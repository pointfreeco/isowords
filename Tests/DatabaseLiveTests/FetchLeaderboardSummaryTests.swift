import CustomDump
import Overture
import PostgresKit
import XCTest

@testable import DatabaseClient
@testable import DatabaseLive
@testable import SharedModels

class FetchLeaderboardSummaryTests: DatabaseTestCase {
  func testFetchLeaderboardSummary() throws {
    let players = try (1...3).map { index in
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

    let dates: [TimeScope: Date] = [
      .lastDay: Date().addingTimeInterval(-60 * 60 * 12),
      .lastWeek: Date().addingTimeInterval(-60 * 60 * 24 * 5),
      .allTime: Date().addingTimeInterval(-60 * 60 * 24 * 10),
    ]

    let scores: [TimeScope: [Int]] = [
      .lastDay: [1_000, 500, 200],
      .lastWeek: [600, 1_500, 500],
      .allTime: [200, 400, 2_000],
    ]

    var puzzles = createPuzzlesIterator()

    var leaderboardIds: [TimeScope: [(LeaderboardScore.Id, Player.Id)]] = [:]
    try dates.forEach { timeScope, date in
      try players.enumerated().forEach { index, player in
        let leaderboardId = try self.pool.database(logger: Logger(label: "Postgres"))
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
              \(bind: scores[timeScope]?[index]),
              \(bind: date)
            )
            RETURNING "id"
            """
          )
          .first()
          .run.perform().unwrap()?
          .decode(column: "id", as: LeaderboardScore.Id.self)

        guard let id = leaderboardId
        else { return }
        leaderboardIds[timeScope, default: []].append((id, player.id))
      }
    }

    var summaries: [TimeScope: [LeaderboardScoreResult.Rank]] = [:]
    try leaderboardIds[.lastDay]?.forEach { leaderboardScoreId, playerId in
      try TimeScope.soloCases.forEach { timeScope in
        summaries[timeScope, default: []].append(
          try self.database.fetchLeaderboardSummary(
            .init(
              gameMode: .timed,
              timeScope: timeScope,
              type: .player(scoreId: leaderboardScoreId, playerId: playerId)
            )
          )
          .run.perform().unwrap()
        )
      }
    }

    XCTAssertNoDifference(
      summaries,
      [
        .lastDay: [
          .init(outOf: 3, rank: 1),
          .init(outOf: 3, rank: 2),
          .init(outOf: 3, rank: 3),
        ],
        .lastWeek: [
          .init(outOf: 3, rank: 2),
          .init(outOf: 3, rank: 2),
          .init(outOf: 3, rank: 3),
        ],
        .allTime: [
          .init(outOf: 3, rank: 3),
          .init(outOf: 3, rank: 3),
          .init(outOf: 3, rank: 3),
        ],
      ]
    )
  }

  func testFetchLeaderboardSummary_Anonymous() throws {
    let players = try (1...3).map { index in
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

    let dates: [TimeScope: Date] = [
      .lastDay: Date().addingTimeInterval(-60 * 60 * 12),
      .lastWeek: Date().addingTimeInterval(-60 * 60 * 24 * 5),
      .allTime: Date().addingTimeInterval(-60 * 60 * 24 * 10),
    ]

    let scores: [TimeScope: [Int]] = [
      .lastDay: [1_000, 500, 200],
      .lastWeek: [600, 1_500, 500],
      .allTime: [200, 400, 2_000],
    ]

    var puzzles = createPuzzlesIterator()

    var leaderboardIds: [TimeScope: [(LeaderboardScore.Id, Player.Id)]] = [:]
    try dates.forEach { timeScope, date in
      try players.enumerated().forEach { index, player in
        let leaderboardId = try self.pool.database(logger: Logger(label: "Postgres"))
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
              \(bind: scores[timeScope]?[index]),
              \(bind: date)
            )
            RETURNING "id"
            """
          )
          .first()
          .run.perform().unwrap()?
          .decode(column: "id", as: LeaderboardScore.Id.self)

        guard let id = leaderboardId
        else { return }
        leaderboardIds[timeScope, default: []].append((id, player.id))
      }
    }

    var summaries: [TimeScope: [LeaderboardScoreResult.Rank]] = [:]
    try leaderboardIds[.lastDay]?.forEach { leaderboardScoreId, playerId in
      try TimeScope.soloCases.forEach { timeScope in
        summaries[timeScope, default: []].append(
          try self.database.fetchLeaderboardSummary(
            .init(
              gameMode: .timed,
              timeScope: timeScope,
              type: .anonymous(score: 1_100)
            )
          )
          .run.perform().unwrap()
        )
      }
    }

    XCTAssertNoDifference(
      summaries,
      [
        .lastDay: [
          .init(outOf: 4, rank: 1),
          .init(outOf: 4, rank: 1),
          .init(outOf: 4, rank: 1),
        ],
        .lastWeek: [
          .init(outOf: 4, rank: 2),
          .init(outOf: 4, rank: 2),
          .init(outOf: 4, rank: 2),
        ],
        .allTime: [
          .init(outOf: 4, rank: 3),
          .init(outOf: 4, rank: 3),
          .init(outOf: 4, rank: 3),
        ],
      ]
    )
  }
}
