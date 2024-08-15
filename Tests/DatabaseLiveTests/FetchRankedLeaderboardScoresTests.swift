import CustomDump
import Overture
import PostgresKit
import XCTest

@testable import DatabaseClient
@testable import DatabaseLive
@testable import SharedModels

class FetchRankedLeaderboardScoresTests: DatabaseTestCase {
  func testFetchRankedLeaderboardScores() throws {
    let player = try self.database.insertPlayer(.blob)
      .run.perform().unwrap()

    let dates = [
      Date().addingTimeInterval(-7_200),  // 2 hours ago
      Date().addingTimeInterval(-345_600),  // 4 days ago
      Date().addingTimeInterval(-1_209_600),  // two weeks ago
    ]

    var puzzles = createPuzzlesIterator()

    let leaderboardScoreIds = try dates.enumerated().map { idx, date in
      try XCTUnwrap(
        try self.pool.database(logger: Logger(label: "Postgres"))
          .sql()
          .raw(
            """
            INSERT INTO "leaderboardScores"
            ("gameContext", "gameMode", "language", "moves", "playerId", "puzzle", "score", "createdAt")
            VALUES
            (
              \(bind: DatabaseClient.SubmitLeaderboardScore.GameContext.solo),
              \(bind: GameMode.timed),
              \(bind: Language.en),
              \(bind: [] as Moves),
              \(bind: player.id),
              \(bind: puzzles.next()!),
              \(bind: 1_000 + 1_000 * idx),
              \(bind: date)
            )
            RETURNING "id"
            """
          )
          .first()
          .run.perform().unwrap()?
          .decode(column: "id", as: LeaderboardScore.Id.self)
      )
    }

    let dailyChallenge = try self.database.createTodaysDailyChallenge(
      .init(gameMode: .timed, language: .en, puzzle: .mock)
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
        puzzle: .mock,
        score: 1_500,
        words: [
          .init(moveIndex: 0, score: 1_500, word: "BAMBOOZLED")
        ]
      )
    )
    .run.perform().unwrap()

    // Create a turn based score to make sure it is not included in results.
    _ = try self.database.submitLeaderboardScore(
      .init(
        dailyChallengeId: nil,
        gameContext: .turnBased,
        gameMode: .timed,
        language: .en,
        moves: [],
        playerId: player.id,
        puzzle: .mock,
        score: 100_000,
        words: []
      )
    )
    .run.perform().unwrap()

    let lastDayScores = try self.database.fetchRankedLeaderboardScores(
      .init(
        gameMode: .timed,
        language: .en,
        playerId: player.id,
        timeScope: .lastDay
      )
    )
    .run.perform().unwrap()

    expectNoDifference(
      lastDayScores,
      [
        .init(
          id: leaderboardScoreIds[0],
          isSupporter: false,
          isYourScore: true,
          outOf: 1,
          playerDisplayName: "Blob",
          rank: 1,
          score: 1_000
        )
      ]
    )

    let lastWeekScores = try self.database.fetchRankedLeaderboardScores(
      .init(
        gameMode: .timed,
        language: .en,
        playerId: player.id,
        timeScope: .lastWeek
      )
    )
    .run.perform().unwrap()

    expectNoDifference(
      lastWeekScores,
      [
        .init(
          id: leaderboardScoreIds[1],
          isSupporter: false,
          isYourScore: true,
          outOf: 1,
          playerDisplayName: "Blob",
          rank: 1,
          score: 2_000
        )
      ]
    )

    let allTimeScores = try self.database.fetchRankedLeaderboardScores(
      .init(
        gameMode: .timed,
        language: .en,
        playerId: player.id,
        timeScope: .allTime
      )
    )
    .run.perform().unwrap()

    expectNoDifference(
      allTimeScores,
      [
        .init(
          id: leaderboardScoreIds[2],
          isSupporter: false,
          isYourScore: true,
          outOf: 1,
          playerDisplayName: "Blob",
          rank: 1,
          score: 3_000
        )
      ]
    )
  }

  func testFetchRankedLeaderboardScores_DailyChallengesGetExtraTime() throws {
    var puzzles = createPuzzlesIterator()

    let player = try self.database.insertPlayer(.blob)
      .run.perform().unwrap()

    let yesterdaysPuzzle = puzzles.next()!
    let yesterdayDailyChallenge = try XCTUnwrap(
      try self.pool.database(logger: Logger(label: "Postgres")).sql().raw(
        """
        INSERT INTO "dailyChallenges"
        ("gameMode", "gameNumber", "language", "puzzle")
        VALUES
        (
          \(bind: GameMode.unlimited),
          CURRENT_DAILY_CHALLENGE_NUMBER() - 1,
          \(bind: Language.en),
          \(bind: yesterdaysPuzzle)
        )
        RETURNING
          *,
          DATE_TRUNC('DAY', "createdAt" + INTERVAL '1 DAY') AS "endsAt"
        """
      )
      .first().run.perform().unwrap()?.decode(model: SharedModels.DailyChallenge.self)
    )

    let yesterdayDailyChallengeScore = try XCTUnwrap(
      try self.pool.database(logger: Logger(label: "Postgres")).sql().raw(
        """
        INSERT INTO "leaderboardScores"
        ("gameContext", "dailyChallengeId", "gameMode", "language", "moves", "playerId", "puzzle", "score", "createdAt")
        VALUES
        (
          \(bind: DatabaseClient.SubmitLeaderboardScore.GameContext.dailyChallenge),
          \(bind: yesterdayDailyChallenge.id),
          \(bind: GameMode.unlimited),
          \(bind: Language.en),
          \(bind: [] as Moves),
          \(bind: player.id),
          \(bind: yesterdaysPuzzle),
          \(bind: 0),
          DATE_TRUNC('DAY', NOW() - INTERVAL '1 DAY') + INTERVAL '1 SECOND'
        )
        RETURNING *
        """
      )
      .first().run.perform().unwrap()?.decode(model: SharedModels.LeaderboardScore.self)
    )

    let todaysPuzzle = puzzles.next()!
    let todaysDailyChallenge = try self.database.createTodaysDailyChallenge(
      .init(gameMode: .unlimited, language: .en, puzzle: todaysPuzzle)
    ).run.perform().unwrap()
    _ = try self.database.submitLeaderboardScore(
      .init(
        dailyChallengeId: todaysDailyChallenge.id, gameContext: .dailyChallenge,
        gameMode: .unlimited, language: .en, moves: [], playerId: player.id, puzzle: todaysPuzzle,
        score: 0, words: [])
    )
    .run.perform().unwrap()

    let scores = try self.database.fetchRankedLeaderboardScores(
      .init(gameMode: .unlimited, language: .en, playerId: player.id, timeScope: .lastDay)
    )
    .run.perform().unwrap()

    expectNoDifference(
      scores,
      [
        .init(
          id: yesterdayDailyChallengeScore.id,
          isSupporter: false,
          isYourScore: true,
          outOf: 1,
          playerDisplayName: player.displayName,
          rank: 1,
          score: 0
        )
      ]
    )
  }

  func testFetchRankedLeaderboardScores_WithSupporter() throws {
    let player = try self.database.insertPlayer(.blob)
      .run.perform().unwrap()
    try self.database.updateAppleReceipt(player.id, .mock)
      .run.perform().unwrap()

    let score = try self.database.submitLeaderboardScore(
      .init(
        dailyChallengeId: nil,
        gameContext: .solo,
        gameMode: .timed,
        language: .en,
        moves: [],
        playerId: player.id,
        puzzle: .mock,
        score: 0,
        words: []
      )
    )
    .run.perform().unwrap()

    let entries = try self.database.fetchRankedLeaderboardScores(
      .init(
        gameMode: .timed,
        language: .en,
        playerId: player.id,
        timeScope: .allTime
      )
    )
    .run.perform().unwrap()

    expectNoDifference(
      entries,
      [
        .init(
          id: score.id,
          isSupporter: true,
          isYourScore: true,
          outOf: 1,
          playerDisplayName: player.displayName,
          rank: 1,
          score: 0
        )
      ]
    )
  }
}
