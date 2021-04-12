import ComposableArchitecture
import Overture
import SharedModels
import Sqlite

extension LocalDatabaseClient {
  public static func live(path: URL) -> Self {
    var _db: Sqlite!
    func db() throws -> Sqlite {
      if _db == nil {
        try! FileManager.default.createDirectory(
          at: path.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        _db = try Sqlite(path: path.absoluteString)
      }
      return _db
    }
    return Self(
      fetchGamesForWord: { word in .catching { try db().fetchGames(for: word) } },
      fetchStats: .catching { try db().fetchStats() },
      fetchVocab: .catching { try db().fetchVocab() },
      migrate: .catching { try db().migrate() },
      playedGamesCount: { gameContext in
        .catching { try db().playedGamesCount(gameContext: gameContext) }
      },
      saveGame: { game in .catching { try db().saveGame(game) } }
    )
  }

  public static func autoMigratingLive(path: URL) -> Self {
    let client = Self.live(path: path)
    _ = client.migrate.sink(receiveCompletion: { _ in }, receiveValue: {})
    return client
  }
}

private let jsonEncoder = JSONEncoder()
private let jsonDecoder = JSONDecoder()

extension Sqlite {
  func fetchGames(for word: String) throws -> [LocalDatabaseClient.Game] {
    return try self.run(
      """
      SELECT
        "id", "completedGame", "gameMode", "secondsPlayed", "startedAt"
      FROM
        "games"
      WHERE "games"."id" IN (
        SELECT "gameId" FROM "moves"
        WHERE "moves"."playedWord" = ?
      )
      ORDER BY "startedAt"
      """,
      .text(word)
    )
    .compactMap { row -> LocalDatabaseClient.Game? in
      try zip(
        (/Sqlite.Datatype.integer).extract(from: row[0]).map(Int.init),
        (/Sqlite.Datatype.text).extract(from: row[1])
          .map { try jsonDecoder.decode(CompletedGame.self, from: Data($0.utf8)) },
        (/Sqlite.Datatype.text).extract(from: row[2]).flatMap(GameMode.init(rawValue:)),
        (/Sqlite.Datatype.integer).extract(from: row[3]).map(Int.init),
        (/Sqlite.Datatype.real).extract(from: row[4]).map(Date.init(timeIntervalSince1970:))
      )
      .map(LocalDatabaseClient.Game.init(id:completedGame:gameMode:secondsPlayed:startedAt:))
    }
  }

  func fetchStats() throws -> LocalDatabaseClient.Stats {
    let averageWordLengthRows = try self.run(
      """
      SELECT AVG(LENGTH("playedWord"))
      FROM "moves"
      WHERE "type" = 'playedWord'
      """
    )
    let averageWordLength = (/Sqlite.Datatype.real)
      .extract(from: averageWordLengthRows[0][0])

    let gamesPlayedRows = try self.run(
      """
      SELECT COUNT(*) FROM "games"
      """
    )
    let gamesPlayed =
      (/Sqlite.Datatype.integer)
      .extract(from: gamesPlayedRows[0][0])
      .map(Int.init)
      ?? 0

    let highestScoringWordRows = try self.run(
      """
      SELECT "playedWord", MAX("score")
      FROM "moves"
      WHERE "type" = 'playedWord'
      """
    )
    let highestScoringWord = zip(
      (/Sqlite.Datatype.text).extract(from: highestScoringWordRows[0][0]),
      (/Sqlite.Datatype.integer).extract(from: highestScoringWordRows[0][1]).map(Int.init)
    )
    .map(LocalDatabaseClient.Stats.Word.init(letters:score:))

    func highScore(gameMode: GameMode) throws -> Int? {
      let rows = try self.run(
        """
        SELECT sum("score") AS "score" FROM "moves"
        JOIN "games" ON "games"."id" = "moves"."gameId"
        WHERE "games"."gameMode" = ?
        GROUP BY "gameId"
        ORDER BY "score" DESC
        LIMIT 1
        """,
        .text(gameMode.rawValue)
      )
      return rows
        .first?
        .first
        .flatMap {
          (/Sqlite.Datatype.integer).extract(from: $0)
            .map(Int.init)
        }
    }

    let highScoreTimed = try highScore(gameMode: .timed)
    let highScoreUnlimited = try highScore(gameMode: .unlimited)

    let longestWordRows = try self.run(
      """
      SELECT "playedWord"
      FROM "moves"
      WHERE "type" = 'playedWord'
      ORDER BY LENGTH("playedWord") DESC, "score" DESC
      LIMIT 1
      """
    )
    let longestWord =
      longestWordRows.isEmpty
      ? nil
      : (/Sqlite.Datatype.text)
        .extract(from: longestWordRows[0][0])

    let secondsPlayedRows = try self.run(
      """
      SELECT SUM("secondsPlayed") FROM "games"
      """
    )
    let secondsPlayed =
      (/Sqlite.Datatype.integer)
      .extract(from: secondsPlayedRows[0][0])
      .map(Int.init)
      ?? 0

    let wordsFoundRows = try self.run(
      """
      SELECT COUNT(DISTINCT "playedWord")
      FROM "moves"
      WHERE "type" = 'playedWord'
      """
    )
    let wordsFound =
      (/Sqlite.Datatype.integer)
      .extract(from: wordsFoundRows[0][0])
      .map(Int.init)
      ?? 0

    return LocalDatabaseClient.Stats(
      averageWordLength: averageWordLength,
      gamesPlayed: gamesPlayed,
      highestScoringWord: highestScoringWord,
      highScoreTimed: highScoreTimed,
      highScoreUnlimited: highScoreUnlimited,
      longestWord: longestWord,
      secondsPlayed: secondsPlayed,
      wordsFound: wordsFound
    )
  }

  func fetchVocab() throws -> LocalDatabaseClient.Vocab {
    let vocabRows = try self.run(
      """
      SELECT "playedWord", COUNT("playedWord"), score
      FROM "moves"
      WHERE "type" = 'playedWord'
      GROUP BY "playedWord"
      ORDER BY "score" DESC, LENGTH("playedWord") DESC, "playedWord" ASC
      """
    )
    return LocalDatabaseClient.Vocab(
      words:
        vocabRows
        .compactMap { row in
          zip(
            (/Sqlite.Datatype.text).extract(from: row[0]),
            (/Sqlite.Datatype.integer).extract(from: row[1]).map(Int.init),
            (/Sqlite.Datatype.integer).extract(from: row[2]).map(Int.init)
          )
          .map(LocalDatabaseClient.Vocab.Word.init(letters:playCount:score:))
        }
    )
  }

  func migrate() throws {
    try self.execute(
      """
      CREATE TABLE IF NOT EXISTS "games" (
        "id" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL UNIQUE,
        "completedGame" TEXT NOT NULL,
        "gameContext" TEXT NOT NULL,
        "gameMode" TEXT NOT NULL,
        "secondsPlayed" INTEGER NOT NULL,
        "startedAt" TIMESTAMP NOT NULL
      );
      CREATE TABLE IF NOT EXISTS "moves" (
        "id" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL UNIQUE,
        "gameId" INTEGER NOT NULL,
        "playedAt" TIMESTAMP NOT NULL,
        "playedWord" TEXT,
        "removedCube" TEXT,
        "score" INTEGER NOT NULL,
        "type" TEXT NOT NULL,
        FOREIGN KEY ("gameId") REFERENCES "games" ("id")
      );
      """
    )
  }

  func playedGamesCount(gameContext: LocalDatabaseClient.GameContext) throws -> Int {
    struct PlayedGamesCountError: Swift.Error {}

    let rows = try self.run(
      """
      SELECT COUNT(*)
      FROM "games"
      WHERE "gameContext" = ?
      """,
      .text(gameContext.rawValue)
    )

    guard
      let firstRow = rows.first,
      let firstColumn = firstRow.first,
      let count = (/Sqlite.Datatype.integer).extract(from: firstColumn)
    else {
      throw PlayedGamesCountError()
    }
    return Int(count)
  }

  func saveGame(_ game: CompletedGame) throws {
    try self.run(
      """
      INSERT INTO "games" (
        "completedGame", "gameContext", "gameMode", "secondsPlayed", "startedAt"
      )
      VALUES (
        ?, ?, ?, ?, ?
      );
      """,
      .text(String(decoding: try jsonEncoder.encode(game), as: UTF8.self)),
      .text(LocalDatabaseClient.GameContext(gameContext: game.gameContext).rawValue),
      .text(game.gameMode.rawValue),
      .integer(Int32(game.secondsPlayed)),
      .real(game.gameStartTime.timeIntervalSince1970)
    )
    let id = self.lastInsertRowid
    for move in game.localMoves {
      let type: String
      let playedWord: String?
      let removedCube: String?
      switch move.type {
      case let .playedWord(selectedFaces):
        type = "playedWord"
        playedWord = game.cubes.string(from: selectedFaces).rawValue
        removedCube = nil
      case let .removedCube(index):
        type = "removedCube"
        playedWord = nil
        removedCube = try String(decoding: jsonEncoder.encode(index), as: UTF8.self)
      }
      try self.run(
        """
        INSERT INTO "moves" (
          "gameId", "playedAt", "playedWord", "removedCube", "score", "type"
        )
        VALUES (
          ?, ?, ?, ?, ?, ?
        );
        """,
        .integer(Int32(id)),
        .real(move.playedAt.timeIntervalSince1970),
        playedWord.map(Datatype.text) ?? .null,
        removedCube.map(Datatype.text) ?? .null,
        .integer(Int32(move.score)),
        .text(type)
      )
    }
  }
}
