import Overture
import PostgresKit
import XCTest

@testable import DatabaseClient
@testable import DatabaseLive
@testable import SharedModels

class DatabaseLiveTests: DatabaseTestCase {
  func testTodayDailyChallenge() throws {
    let createdChallenge = try self.database.createTodaysDailyChallenge(
      .init(
        gameMode: .timed,
        language: .en,
        puzzle: .mock
      )
    )
    .run.perform().unwrap()

    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-dd-mm"
    let gameNumber = DailyChallenge.GameNumber(
      rawValue: Int(
        Date.timeIntervalSinceReferenceDate
          - formatter.date(from: "2020-01-01")!.timeIntervalSinceReferenceDate)
        / 86_400
    )

    XCTAssertEqual(createdChallenge.gameMode, .timed)
    XCTAssertEqual(createdChallenge.gameNumber, gameNumber)
    XCTAssertEqual(
      createdChallenge.id,
      .init(rawValue: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!))
    XCTAssertEqual(createdChallenge.language, .en)
    XCTAssertEqual(createdChallenge.puzzle, .mock)

    let fetchedChallenge = try self.database.fetchDailyChallengeById(createdChallenge.id)
      .run.perform().unwrap()

    XCTAssertEqual(fetchedChallenge.gameMode, .timed)
    XCTAssertEqual(fetchedChallenge.gameNumber, gameNumber)
    XCTAssertEqual(
      fetchedChallenge.id,
      .init(rawValue: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!))
    XCTAssertEqual(fetchedChallenge.language, .en)
    XCTAssertEqual(fetchedChallenge.puzzle, .mock)

    let todaysChallenges = try self.database.fetchTodaysDailyChallenges(.en)
      .run.perform().unwrap()

    XCTAssertEqual(todaysChallenges.count, 1)
    XCTAssertEqual(todaysChallenges[0].gameMode, .timed)
    XCTAssertEqual(todaysChallenges[0].gameNumber, gameNumber)
    XCTAssertEqual(
      todaysChallenges[0].id,
      .init(rawValue: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!))
    XCTAssertEqual(todaysChallenges[0].language, .en)
    XCTAssertEqual(todaysChallenges[0].puzzle, .mock)
  }

  func testSubmitDailyChallengeScore() throws {
    let puzzle = update(ArchivablePuzzle.mock) {
      $0.0.0.0 = ArchivableCube(
        left: .init(letter: "A", side: .left),
        right: .init(letter: "B", side: .right),
        top: .init(letter: "C", side: .top)
      )
    }
    let createdChallenge = try self.database.createTodaysDailyChallenge(
      .init(
        gameMode: .timed,
        language: .en,
        puzzle: puzzle
      )
    )
    .run.perform().unwrap()

    let createdPlayer = try self.database.insertPlayer(.blob)
      .run.perform().unwrap()

    _ = try self.database.submitLeaderboardScore(
      .init(
        dailyChallengeId: createdChallenge.id,
        gameContext: .dailyChallenge,
        gameMode: .timed,
        language: .en,
        moves: [
          .init(
            playedAt: Date(timeIntervalSince1970: 1_234_567_890),
            playerIndex: nil,
            reactions: nil,
            score: 10,
            type: .playedWord([
              .init(index: .zero, side: .left),
              .init(index: .zero, side: .right),
              .init(index: .zero, side: .top),
            ])
          )
        ],
        playerId: createdPlayer.id,
        puzzle: puzzle,
        score: 10,
        words: [.init(moveIndex: 0, score: 10, word: "ABC")]
      )
    )
    .run.perform().unwrap()
  }

  func testSubmitLeaderboardScore() throws {
    let createdPlayer = try self.database.insertPlayer(.blob)
      .run.perform().unwrap()

    let score = try self.database.submitLeaderboardScore(
      .init(
        dailyChallengeId: nil,
        gameContext: .solo,
        gameMode: .timed,
        language: .en,
        moves: [
          .init(
            playedAt: Date(timeIntervalSince1970: 1_234_567_890),
            playerIndex: nil,
            reactions: nil,
            score: 10,
            type: .playedWord([
              .init(index: .zero, side: .left),
              .init(index: .zero, side: .right),
              .init(index: .zero, side: .top),
            ])
          )
        ],
        playerId: createdPlayer.id,
        puzzle: .mock,
        score: 10,
        words: [
          .init(
            moveIndex: 0,
            score: 10,
            word: "ABC"
          )
        ]
      )
    )
    .run.perform().unwrap()

    let words = try self.pool.database(logger: Logger(label: "Postgres"))
      .sql()
      .raw("SELECT * FROM words")
      .all(decoding: Word.self)
      .run.perform().unwrap()

    guard words.count == 1
    else {
      XCTFail("words array should hold one word.")
      return
    }

    XCTAssertEqual(
      words,
      [
        Word(
          createdAt: words[0].createdAt,
          id: .init(rawValue: UUID(uuidString: "00000000-0000-0000-0000-000000000004")!),
          leaderboardScoreId: .init(
            rawValue: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!),
          moveIndex: 0,
          score: 10,
          word: "ABC"
        )
      ]
    )

    XCTAssertEqual(score.gameMode, .timed)
    XCTAssertEqual(
      score.id, .init(rawValue: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!))
    XCTAssertEqual(score.language, .en)
    XCTAssertEqual(
      score.moves,
      [
        .init(
          playedAt: Date(timeIntervalSince1970: 1_234_567_890),
          playerIndex: nil,
          reactions: nil,
          score: 10,
          type: .playedWord([
            .init(index: .zero, side: .left),
            .init(index: .zero, side: .right),
            .init(index: .zero, side: .top),
          ])
        )
      ]
    )
    XCTAssertEqual(score.playerId, createdPlayer.id)
    XCTAssertEqual(score.puzzle, .mock)
    XCTAssertEqual(score.score, 10)
  }

  func testSubmitLeaderboardScore_Duplicate() throws {
    let createdPlayer = try self.database.insertPlayer(.blob)
      .run.perform().unwrap()

    let submitRequest = DatabaseClient.SubmitLeaderboardScore(
      dailyChallengeId: nil,
      gameContext: .solo,
      gameMode: .timed,
      language: .en,
      moves: [
        .init(
          playedAt: Date(timeIntervalSince1970: 1_234_567_890),
          playerIndex: nil,
          reactions: nil,
          score: 10,
          type: .playedWord([
            .init(index: .zero, side: .left),
            .init(index: .zero, side: .right),
            .init(index: .zero, side: .top),
          ])
        )
      ],
      playerId: createdPlayer.id,
      puzzle: .mock,
      score: 10,
      words: [
        .init(
          moveIndex: 0,
          score: 10,
          word: "ABC"
        )
      ]
    )
    let score1 = try self.database.submitLeaderboardScore(submitRequest)
      .run.perform().unwrap()
    let score2 = try self.database.submitLeaderboardScore(submitRequest)
      .run.perform().unwrap()

    let words = try self.pool.database(logger: Logger(label: "Postgres"))
      .sql()
      .raw("SELECT * FROM words")
      .all(decoding: Word.self)
      .run.perform().unwrap()

    guard words.count == 1
    else {
      XCTFail("words array should hold one word.")
      return
    }

    XCTAssertEqual(
      words,
      [
        Word(
          createdAt: words[0].createdAt,
          id: .init(rawValue: UUID(uuidString: "00000000-0000-0000-0000-000000000004")!),
          leaderboardScoreId: .init(
            rawValue: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!),
          moveIndex: 0,
          score: 10,
          word: "ABC"
        )
      ]
    )

    XCTAssertEqual(score1.gameMode, .timed)
    XCTAssertEqual(
      score1.id, .init(rawValue: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!))
    XCTAssertEqual(score1.language, .en)
    XCTAssertEqual(
      score1.moves,
      [
        .init(
          playedAt: Date(timeIntervalSince1970: 1_234_567_890),
          playerIndex: nil,
          reactions: nil,
          score: 10,
          type: .playedWord([
            .init(index: .zero, side: .left),
            .init(index: .zero, side: .right),
            .init(index: .zero, side: .top),
          ])
        )
      ]
    )
    XCTAssertEqual(score1.playerId, createdPlayer.id)
    XCTAssertEqual(score1.puzzle, .mock)
    XCTAssertEqual(score1.score, 10)
    XCTAssertEqual(score2, score1)
  }

  func testInsertPlayer() throws {
    let createdPlayer = try self.database.insertPlayer(.blob)
      .run.perform().unwrap()

    XCTAssertEqual(
      createdPlayer.accessToken,
      .init(rawValue: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!)
    )
    XCTAssertEqual(
      createdPlayer.deviceId,
      .init(rawValue: UUID(uuidString: "deadbeef-dead-beef-dead-beefdeadbeef")!)
    )
    XCTAssertEqual(createdPlayer.displayName, "Blob")
    XCTAssertEqual(createdPlayer.gameCenterLocalPlayerId, "_id:blob")
    XCTAssertEqual(
      createdPlayer.id,
      .init(rawValue: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!)
    )

    let fetchedPlayerByAccessToken = try self.database.fetchPlayerByAccessToken(
      .init(rawValue: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!)
    )
    .run.perform().unwrap()

    let fetchedPlayerByDeviceId = try self.database.fetchPlayerByDeviceId(
      .init(rawValue: UUID(uuidString: "deadbeef-dead-beef-dead-beefdeadbeef")!)
    )
    .run.perform().unwrap()

    let fetchedPlayerByGameCenterId = try self.database.fetchPlayerByGameCenterLocalPlayerId(
      "_id:blob"
    )
    .run.perform().unwrap()

    XCTAssertEqual(createdPlayer, fetchedPlayerByAccessToken)
    XCTAssertEqual(createdPlayer, fetchedPlayerByDeviceId)
    XCTAssertEqual(createdPlayer, fetchedPlayerByGameCenterId)
  }

  func testUpdateAppleReceipt() throws {
    let createdPlayer = try self.database.insertPlayer(.blob)
      .run.perform().unwrap()

    try self.database.updateAppleReceipt(createdPlayer.id, .mock)
      .run.perform().unwrap()
  }

  func testUpdatePlayer() throws {
    let createdPlayer = try self.database.insertPlayer(.blob)
      .run.perform().unwrap()

    let player = try self.database.updatePlayer(
      .init(
        displayName: "Blob Jr",
        gameCenterLocalPlayerId: "_id:blob-jr",
        playerId: createdPlayer.id,
        timeZone: "America/New_York"
      )
    )
    .run.perform().unwrap()

    XCTAssertEqual(
      player.accessToken,
      .init(rawValue: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!)
    )
    XCTAssertEqual(
      player.deviceId,
      .init(rawValue: UUID(uuidString: "deadbeef-dead-beef-dead-beefdeadbeef")!)
    )
    XCTAssertEqual(player.displayName, "Blob Jr")
    XCTAssertEqual(player.gameCenterLocalPlayerId, "_id:blob-jr")
    XCTAssertEqual(
      player.id,
      .init(rawValue: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!)
    )
  }

  func testFetchDailyChallengeResult() throws {
    let puzzle = update(ArchivablePuzzle.mock) {
      $0.0.0.0 = ArchivableCube(
        left: .init(letter: "A", side: .left),
        right: .init(letter: "B", side: .right),
        top: .init(letter: "C", side: .top)
      )
    }
    let players = try (1...4).map { index in
      try self.database.insertPlayer(
        .init(
          deviceId: .init(
            rawValue: UUID(uuidString: "deadbeef-dead-beef-dead-beefdeadbee\(index)")!),
          displayName: "Blob \(index)",
          gameCenterLocalPlayerId: .init(rawValue: "_id:blob_\(index)"),
          timeZone: "America/New_York"
        )
      )
      .run.perform().unwrap()
    }

    let dailyChallenge = try self.database.createTodaysDailyChallenge(
      .init(gameMode: .timed, language: .en, puzzle: puzzle)
    )
    .run.perform().unwrap()

    let scores = [1_000, 2_000, 3_000, 2_000]

    try zip(scores, players).forEach { score, player in
      _ = try self.database.submitLeaderboardScore(
        .init(
          dailyChallengeId: dailyChallenge.id,
          gameContext: .dailyChallenge,
          gameMode: .timed,
          language: .en,
          moves: [],
          playerId: player.id,
          puzzle: puzzle,
          score: score,
          words: [.init(moveIndex: 0, score: score, word: "ABC")]
        )
      )
      .run.perform().unwrap()
    }

    let results = try players.map { player in
      try self.database.fetchDailyChallengeResult(
        .init(dailyChallengeId: dailyChallenge.id, playerId: player.id)
      )
      .run.perform().unwrap()
    }

    XCTAssertEqual(
      results,
      [
        .init(outOf: 3, rank: 3, score: 1_000),
        .init(outOf: 3, rank: 2, score: 2_000),
        .init(outOf: 3, rank: 1, score: 3_000),
        .init(outOf: 3, rank: 2, score: 2_000),
      ]
    )
  }

  func testInsertSharedGame() throws {
    let completedGame = CompletedGame(
      cubes: .mock,
      gameContext: .solo,
      gameMode: .timed,
      gameStartTime: .init(timeIntervalSince1970: 1_234_567_890),
      language: .en,
      moves: [
        .init(
          playedAt: .init(timeIntervalSince1970: 1_234_567_890),
          playerIndex: nil,
          reactions: nil,
          score: 0,
          type: .removedCube(.zero)
        ),
        .init(
          playedAt: .init(timeIntervalSince1970: 1_234_567_890),
          playerIndex: nil,
          reactions: nil,
          score: 10,
          type: .playedWord([
            .init(index: .init(x: .zero, y: .zero, z: .one), side: .left),
            .init(index: .init(x: .zero, y: .zero, z: .one), side: .right),
            .init(index: .init(x: .zero, y: .zero, z: .one), side: .top),
          ])
        ),
      ],
      secondsPlayed: 0
    )

    let createdPlayer = try self.database.insertPlayer(.blob)
      .run.perform().unwrap()

    let sharedGame = try self.database.insertSharedGame(completedGame, createdPlayer)
      .run.perform().unwrap()

    XCTAssertEqual(
      sharedGame,
      .init(
        code: sharedGame.code,
        createdAt: sharedGame.createdAt,
        gameMode: .timed,
        id: .init(rawValue: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!),
        language: .en,
        moves: completedGame.moves,
        playerId: createdPlayer.id,
        puzzle: completedGame.cubes
      )
    )

    let fetchedSharedGame = try self.database.fetchSharedGame(sharedGame.code)
      .run.perform().unwrap()

    XCTAssertEqual(
      fetchedSharedGame,
      sharedGame
    )
  }

  func testFetchVocabLeaderboard() throws {
    var puzzles = createPuzzlesIterator()

    let player = try self.database.insertPlayer(.blob)
      .run.perform().unwrap()

    _ = try self.database.submitLeaderboardScore(
      .init(
        dailyChallengeId: nil,
        gameContext: .solo,
        gameMode: .timed,
        language: .en,
        moves: [],
        playerId: player.id,
        puzzle: puzzles.next()!,
        score: 0,
        words: [
          .init(moveIndex: 0, score: 100, word: "SHRIMP"),
          .init(moveIndex: 0, score: 20, word: "MATH"),
          .init(moveIndex: 0, score: 150, word: "ZZZZ"),
          .init(moveIndex: 0, score: 500, word: "LOGOPHILES"),
        ]
      )
    )
    .run.perform().unwrap()

    let dailyChallengePuzzle = puzzles.next()!
    let dailyChallenge = try self.database.createTodaysDailyChallenge(
      .init(gameMode: .timed, language: .en, puzzle: dailyChallengePuzzle)
    )
    .run.perform().unwrap()

    _ = try self.database.submitLeaderboardScore(
      .init(
        dailyChallengeId: dailyChallenge.id,
        gameContext: .dailyChallenge,
        gameMode: .timed,
        language: .en,
        moves: [],
        playerId: player.id,
        puzzle: dailyChallengePuzzle,
        score: 1_000,
        words: [
          .init(moveIndex: 0, score: 1_000, word: "BAMBOOZLED")
        ]
      )
    )
    .run.perform().unwrap()

    let entriesSortedByScore = try self.database.fetchVocabLeaderboard(
      .en, player, .allTime, .score
    )
    .run.perform().unwrap()

    XCTAssertEqual(
      entriesSortedByScore,
      [
        .init(
          denseRank: 1,
          isYourScore: true,
          outOf: 4,
          playerDisplayName: "Blob",
          playerId: player.id,
          rank: 1,
          score: 500,
          word: "LOGOPHILES",
          wordId: .init(rawValue: UUID(uuidString: "00000000-0000-0000-0000-000000000007")!)
        ),
        .init(
          denseRank: 2,
          isYourScore: true,
          outOf: 4,
          playerDisplayName: "Blob",
          playerId: player.id,
          rank: 2,
          score: 150,
          word: "ZZZZ",
          wordId: .init(rawValue: UUID(uuidString: "00000000-0000-0000-0000-000000000006")!)
        ),
        .init(
          denseRank: 3,
          isYourScore: true,
          outOf: 4,
          playerDisplayName: "Blob",
          playerId: player.id,
          rank: 3,
          score: 100,
          word: "SHRIMP",
          wordId: .init(rawValue: UUID(uuidString: "00000000-0000-0000-0000-000000000004")!)
        ),
        .init(
          denseRank: 4,
          isYourScore: true,
          outOf: 4,
          playerDisplayName: "Blob",
          playerId: player.id,
          rank: 4,
          score: 20,
          word: "MATH",
          wordId: .init(rawValue: UUID(uuidString: "00000000-0000-0000-0000-000000000005")!)
        ),
      ]
    )

    let entriesSortedByLength = try self.database.fetchVocabLeaderboard(
      .en, player, .allTime, .length
    )
    .run.perform().unwrap()

    XCTAssertEqual(
      entriesSortedByLength,
      [
        .init(
          denseRank: 1,
          isYourScore: true,
          outOf: 4,
          playerDisplayName: "Blob",
          playerId: player.id,
          rank: 1,
          score: 500,
          word: "LOGOPHILES",
          wordId: .init(rawValue: UUID(uuidString: "00000000-0000-0000-0000-000000000007")!)
        ),
        .init(
          denseRank: 2,
          isYourScore: true,
          outOf: 4,
          playerDisplayName: "Blob",
          playerId: player.id,
          rank: 2,
          score: 100,
          word: "SHRIMP",
          wordId: .init(rawValue: UUID(uuidString: "00000000-0000-0000-0000-000000000004")!)
        ),
        .init(
          denseRank: 3,
          isYourScore: true,
          outOf: 4,
          playerDisplayName: "Blob",
          playerId: player.id,
          rank: 3,
          score: 20,
          word: "MATH",
          wordId: .init(rawValue: UUID(uuidString: "00000000-0000-0000-0000-000000000005")!)
        ),
        .init(
          denseRank: 3,
          isYourScore: true,
          outOf: 4,
          playerDisplayName: "Blob",
          playerId: player.id,
          rank: 3,
          score: 150,
          word: "ZZZZ",
          wordId: .init(rawValue: UUID(uuidString: "00000000-0000-0000-0000-000000000006")!)
        ),
      ]
    )
  }

  func testFetchVocabLeaderboardWord() throws {
    let player = try self.database.insertPlayer(.blob)
      .run.perform().unwrap()

    _ = try self.database.submitLeaderboardScore(
      .init(
        dailyChallengeId: nil,
        gameContext: .solo,
        gameMode: .timed,
        language: .en,
        moves: [
          .init(
            playedAt: .mock,
            playerIndex: nil,
            reactions: nil,
            score: 0,
            type: .removedCube(.init(x: .zero, y: .zero, z: .zero))
          )
        ],
        playerId: player.id,
        puzzle: .mock,
        score: 100,
        words: [
          .init(
            moveIndex: 0,
            score: 100,
            word: "ISOWORDS"
          )
        ]
      )
    )
    .run.perform().unwrap()

    let response = try self.database.fetchVocabLeaderboardWord(
      .init(rawValue: UUID(uuidString: "00000000-0000-0000-0000-000000000004")!)
    )
    .run.perform().unwrap()

    XCTAssertEqual(
      response,
      .init(
        moveIndex: 0,
        moves: [
          .init(
            playedAt: .mock,
            playerIndex: nil,
            reactions: nil,
            score: 0,
            type: .removedCube(.init(x: .zero, y: .zero, z: .zero))
          )
        ],
        playerDisplayName: "Blob",
        playerId: .init(rawValue: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!),
        puzzle: .mock
      )
    )
  }

  func testInsertPushToken() throws {
    let player = try self.database.insertPlayer(.blob)
      .run.perform().unwrap()

    try self.database
      .insertPushToken(
        .init(
          arn: "arn:deadbeef",
          authorizationStatus: .provisional,
          build: 42,
          player: player,
          token: "deadbeef"
        )
      )
      .run.perform().unwrap()

    do {
      let tokens = try self.pool.database(logger: Logger(label: "Postgres"))
        .sql()
        .raw(#"SELECT * FROM "pushTokens""#)
        .all(decoding: PushToken.self)
        .run.perform().unwrap()

      guard tokens.count == 1
      else {
        XCTFail("tokens array should hold one token.")
        return
      }

      XCTAssertEqual(
        tokens,
        [
          PushToken(
            arn: "arn:deadbeef",
            authorizationStatus: .provisional,
            build: 42,
            createdAt: tokens[0].createdAt,
            id: .init(rawValue: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!),
            playerId: .init(rawValue: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!),
            token: "deadbeef"
          )
        ]
      )
    }

    try self.database
      .insertPushToken(
        .init(
          arn: "arn:deadbeef",
          authorizationStatus: .authorized,
          build: 43,
          player: player,
          token: "deadbeef"
        )
      )
      .run.perform().unwrap()

    do {
      let tokens = try self.pool.database(logger: Logger(label: "Postgres"))
        .sql()
        .raw(#"SELECT * FROM "pushTokens""#)
        .all(decoding: PushToken.self)
        .run.perform().unwrap()

      guard tokens.count == 1
      else {
        XCTFail("tokens array should hold one token.")
        return
      }

      XCTAssertEqual(
        tokens,
        [
          PushToken(
            arn: "arn:deadbeef",
            authorizationStatus: .authorized,
            build: 43,
            createdAt: tokens[0].createdAt,
            id: .init(rawValue: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!),
            playerId: .init(rawValue: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!),
            token: "deadbeef"
          )
        ]
      )
    }
  }

  func testUpdatePushSetting() throws {
    var player = try self.database.insertPlayer(.blob)
      .run.perform().unwrap()

    XCTAssertEqual(true, player.sendDailyChallengeReminder)
    XCTAssertEqual(true, player.sendDailyChallengeSummary)

    try self.database
      .updatePushSetting(player.id, .dailyChallengeEndsSoon, false)
      .run.perform().unwrap()

    player = try self.database.fetchPlayerByAccessToken(player.accessToken)
      .run.perform().unwrap().unsafelyUnwrapped

    XCTAssertEqual(false, player.sendDailyChallengeReminder)
    XCTAssertEqual(true, player.sendDailyChallengeSummary)

    try self.database
      .updatePushSetting(player.id, .dailyChallengeReport, false)
      .run.perform().unwrap()

    player = try self.database.fetchPlayerByAccessToken(player.accessToken)
      .run.perform().unwrap().unsafelyUnwrapped

    XCTAssertEqual(false, player.sendDailyChallengeReminder)
    XCTAssertEqual(false, player.sendDailyChallengeSummary)
  }

  func testStartAndCompleteDailyChallenge() throws {
    let player = try self.database.insertPlayer(.blob)
      .run.perform().unwrap()

    try self.database.insertPushToken(
      .init(
        arn: "arn:deadbeef",
        authorizationStatus: .authorized,
        build: 0,
        player: player,
        token: "deadbeef"
      )
    )
    .run.perform().unwrap()

    let dailyChallenge = try self.database.createTodaysDailyChallenge(
      .init(
        gameMode: .unlimited,
        language: .en,
        puzzle: .mock
      )
    )
    .run.perform().unwrap()

    var dailyChallengePlay = try self.database.startDailyChallenge(dailyChallenge.id, player.id)
      .run.perform().unwrap()

    XCTAssertEqual(
      dailyChallengePlay,
      DailyChallengePlay(
        completedAt: nil,
        createdAt: dailyChallengePlay.createdAt,
        dailyChallengeId: dailyChallenge.id,
        id: dailyChallengePlay.id,
        playerId: player.id
      )
    )

    let activeDailyChallengeArns = try self.database.fetchActiveDailyChallengeArns()
      .run.perform().unwrap()

    XCTAssertEqual(
      activeDailyChallengeArns,
      [
        DatabaseClient.DailyChallengeArn(
          arn: "arn:deadbeef", endsAt: activeDailyChallengeArns[0].endsAt)
      ]
    )

    dailyChallengePlay = try self.database.completeDailyChallenge(dailyChallenge.id, player.id)
      .run.perform().unwrap()

    XCTAssertEqual(
      dailyChallengePlay,
      DailyChallengePlay(
        completedAt: dailyChallengePlay.completedAt,
        createdAt: dailyChallengePlay.createdAt,
        dailyChallengeId: dailyChallenge.id,
        id: dailyChallengePlay.id,
        playerId: player.id
      )
    )
    XCTAssertNotNil(dailyChallengePlay.completedAt)

    XCTAssertEqual(
      try self.database.fetchActiveDailyChallengeArns()
        .run.perform().unwrap(),
      []
    )
  }

  func testStartAndFailToCompleteTimedDailyChallenge() throws {
    let player = try self.database.insertPlayer(.blob)
      .run.perform().unwrap()

    try self.database.insertPushToken(
      .init(
        arn: "arn:deadbeef",
        authorizationStatus: .authorized,
        build: 0,
        player: player,
        token: "deadbeef"
      )
    )
    .run.perform().unwrap()

    let dailyChallenge = try self.database.createTodaysDailyChallenge(
      .init(
        gameMode: .timed,
        language: .en,
        puzzle: .mock
      )
    )
    .run.perform().unwrap()

    let dailyChallengePlay = try self.database.startDailyChallenge(dailyChallenge.id, player.id)
      .run.perform().unwrap()

    XCTAssertEqual(
      dailyChallengePlay,
      DailyChallengePlay(
        completedAt: nil,
        createdAt: dailyChallengePlay.createdAt,
        dailyChallengeId: dailyChallenge.id,
        id: dailyChallengePlay.id,
        playerId: player.id
      )
    )

    XCTAssertEqual(
      try self.database.fetchActiveDailyChallengeArns()
        .run.perform().unwrap(),
      []
    )

    let result = try self.database.fetchDailyChallengeResult(
      .init(dailyChallengeId: dailyChallenge.id, playerId: player.id)
    )
    .run.perform().unwrap()

    XCTAssertEqual(
      result,
      .init(outOf: 0, rank: nil, score: nil, started: true)
    )

    XCTAssertEqual(
      try self.database.fetchActiveDailyChallengeArns()
        .run.perform().unwrap(),
      []
    )
  }
}
