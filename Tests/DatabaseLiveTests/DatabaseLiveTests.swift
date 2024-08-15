import CustomDump
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

    expectNoDifference(createdChallenge.gameMode, .timed)
    expectNoDifference(createdChallenge.gameNumber, gameNumber)
    expectNoDifference(
      createdChallenge.id,
      .init(rawValue: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!))
    expectNoDifference(createdChallenge.language, .en)
    expectNoDifference(createdChallenge.puzzle, .mock)

    let fetchedChallenge = try self.database.fetchDailyChallengeById(createdChallenge.id)
      .run.perform().unwrap()

    expectNoDifference(fetchedChallenge.gameMode, .timed)
    expectNoDifference(fetchedChallenge.gameNumber, gameNumber)
    expectNoDifference(
      fetchedChallenge.id,
      .init(rawValue: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!))
    expectNoDifference(fetchedChallenge.language, .en)
    expectNoDifference(fetchedChallenge.puzzle, .mock)

    let todaysChallenges = try self.database.fetchTodaysDailyChallenges(.en)
      .run.perform().unwrap()

    expectNoDifference(todaysChallenges.count, 1)
    expectNoDifference(todaysChallenges[0].gameMode, .timed)
    expectNoDifference(todaysChallenges[0].gameNumber, gameNumber)
    expectNoDifference(
      todaysChallenges[0].id,
      .init(rawValue: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!))
    expectNoDifference(todaysChallenges[0].language, .en)
    expectNoDifference(todaysChallenges[0].puzzle, .mock)
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

    expectNoDifference(
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

    expectNoDifference(score.gameMode, .timed)
    expectNoDifference(
      score.id, .init(rawValue: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!))
    expectNoDifference(score.language, .en)
    expectNoDifference(
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
    expectNoDifference(score.playerId, createdPlayer.id)
    expectNoDifference(score.puzzle, .mock)
    expectNoDifference(score.score, 10)
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

    expectNoDifference(
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

    expectNoDifference(score1.gameMode, .timed)
    expectNoDifference(
      score1.id, .init(rawValue: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!))
    expectNoDifference(score1.language, .en)
    expectNoDifference(
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
    expectNoDifference(score1.playerId, createdPlayer.id)
    expectNoDifference(score1.puzzle, .mock)
    expectNoDifference(score1.score, 10)
    expectNoDifference(score2, score1)
  }

  func testInsertPlayer() throws {
    let createdPlayer = try self.database.insertPlayer(.blob)
      .run.perform().unwrap()

    expectNoDifference(
      createdPlayer.accessToken,
      .init(rawValue: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!)
    )
    expectNoDifference(
      createdPlayer.deviceId,
      .init(rawValue: UUID(uuidString: "deadbeef-dead-beef-dead-beefdeadbeef")!)
    )
    expectNoDifference(createdPlayer.displayName, "Blob")
    expectNoDifference(createdPlayer.gameCenterLocalPlayerId, "_id:blob")
    expectNoDifference(
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

    expectNoDifference(createdPlayer, fetchedPlayerByAccessToken)
    expectNoDifference(createdPlayer, fetchedPlayerByDeviceId)
    expectNoDifference(createdPlayer, fetchedPlayerByGameCenterId)
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

    expectNoDifference(
      player.accessToken,
      .init(rawValue: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!)
    )
    expectNoDifference(
      player.deviceId,
      .init(rawValue: UUID(uuidString: "deadbeef-dead-beef-dead-beefdeadbeef")!)
    )
    expectNoDifference(player.displayName, "Blob Jr")
    expectNoDifference(player.gameCenterLocalPlayerId, "_id:blob-jr")
    expectNoDifference(
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

    expectNoDifference(
      results,
      [
        .init(outOf: 4, rank: 3, score: 1_000),
        .init(outOf: 4, rank: 2, score: 2_000),
        .init(outOf: 4, rank: 1, score: 3_000),
        .init(outOf: 4, rank: 2, score: 2_000),
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

    expectNoDifference(
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

    expectNoDifference(
      fetchedSharedGame,
      sharedGame
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

    expectNoDifference(
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

      expectNoDifference(
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

      expectNoDifference(
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

    expectNoDifference(true, player.sendDailyChallengeReminder)
    expectNoDifference(true, player.sendDailyChallengeSummary)

    try self.database
      .updatePushSetting(player.id, .dailyChallengeEndsSoon, false)
      .run.perform().unwrap()

    player = try self.database.fetchPlayerByAccessToken(player.accessToken)
      .run.perform().unwrap().unsafelyUnwrapped

    expectNoDifference(false, player.sendDailyChallengeReminder)
    expectNoDifference(true, player.sendDailyChallengeSummary)

    try self.database
      .updatePushSetting(player.id, .dailyChallengeReport, false)
      .run.perform().unwrap()

    player = try self.database.fetchPlayerByAccessToken(player.accessToken)
      .run.perform().unwrap().unsafelyUnwrapped

    expectNoDifference(false, player.sendDailyChallengeReminder)
    expectNoDifference(false, player.sendDailyChallengeSummary)
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

    expectNoDifference(
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

    expectNoDifference(
      activeDailyChallengeArns,
      [
        DatabaseClient.DailyChallengeArn(
          arn: "arn:deadbeef", endsAt: activeDailyChallengeArns[0].endsAt)
      ]
    )

    dailyChallengePlay = try self.database.completeDailyChallenge(dailyChallenge.id, player.id)
      .run.perform().unwrap()

    expectNoDifference(
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

    expectNoDifference(
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

    expectNoDifference(
      dailyChallengePlay,
      DailyChallengePlay(
        completedAt: nil,
        createdAt: dailyChallengePlay.createdAt,
        dailyChallengeId: dailyChallenge.id,
        id: dailyChallengePlay.id,
        playerId: player.id
      )
    )

    expectNoDifference(
      try self.database.fetchActiveDailyChallengeArns()
        .run.perform().unwrap(),
      []
    )

    let result = try self.database.fetchDailyChallengeResult(
      .init(dailyChallengeId: dailyChallenge.id, playerId: player.id)
    )
    .run.perform().unwrap()

    expectNoDifference(
      result,
      .init(outOf: 0, rank: nil, score: nil, started: true)
    )

    expectNoDifference(
      try self.database.fetchActiveDailyChallengeArns()
        .run.perform().unwrap(),
      []
    )
  }
}
