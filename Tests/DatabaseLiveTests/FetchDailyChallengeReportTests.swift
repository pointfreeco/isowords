import CustomDump
import Overture
import PostgresKit
import XCTest

@testable import DatabaseClient
@testable import DatabaseLive
@testable import SharedModels

class FetchDailyChallengeReportTests: DatabaseTestCase {
  func testFetchDailyChallengeReport() throws {
    var puzzles = createPuzzlesIterator()

    let player1 = try self.database.insertPlayer(.blob)
      .run.perform().unwrap()
    let player2 = try self.database.insertPlayer(.blobJr)
      .run.perform().unwrap()
    let player3 = try self.database.insertPlayer(.blobSr)
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

    for (player, score) in [(player1, 900), (player2, 1200), (player3, 400)] {
      _ = try XCTUnwrap(
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
            \(bind: score),
            DATE_TRUNC('DAY', NOW() - INTERVAL '1 DAY') + INTERVAL '1 SECOND'
          )
          RETURNING *
          """
        )
        .first().run.perform().unwrap()?.decode(model: SharedModels.LeaderboardScore.self)
      )

      try self.database.insertPushToken(
        .init(
          arn: "arn:deadbeef\(player.gameCenterLocalPlayerId!.rawValue)",
          authorizationStatus: .authorized,
          build: 42,
          player: player,
          token: "deadbeef\(player.gameCenterLocalPlayerId!.rawValue)"
        )
      )
      .run.perform().unwrap()
    }

    let report = try self.database.fetchDailyChallengeReport(
      .init(
        gameMode: .unlimited,
        language: .en
      )
    )
    .run.perform().unwrap()

    expectNoDifference(
      report,
      [
        .init(
          arn: "arn:deadbeef_id:blob_jr",
          gameMode: .unlimited,
          outOf: 3,
          rank: 1,
          score: 1200
        ),
        .init(
          arn: "arn:deadbeef_id:blob",
          gameMode: .unlimited,
          outOf: 3,
          rank: 2,
          score: 900
        ),
        .init(
          arn: "arn:deadbeef_id:blob_sr",
          gameMode: .unlimited,
          outOf: 3,
          rank: 3,
          score: 400
        ),
      ]
    )
  }
}
