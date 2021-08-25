import CustomDump
import Overture
import PostgresKit
import XCTest

@testable import DatabaseClient
@testable import DatabaseLive
@testable import SharedModels

class FetchDailyChallengeResultsTests: DatabaseTestCase {
  func testFetchDailyChallengeResults() throws {
    let player = try self.database.insertPlayer(.blob)
      .run.perform().unwrap()

    XCTAssertNoDifference(
      try self.database.fetchDailyChallengeResults(
        .init(gameMode: .timed, gameNumber: 1, language: .en, playerId: player.id)
      )
      .run.perform().unwrap(),
      []
    )

    let dailyChallenge = try self.database.createTodaysDailyChallenge(
      .init(
        gameMode: .timed,
        language: .en,
        puzzle: .mock
      )
    )
    .run.perform().unwrap()

    let oldDailyChallenge = try self.pool.database(logger: Logger(label: "Postgres"))
      .sql()
      .raw(
        """
        INSERT INTO "dailyChallenges"
        ("gameMode", "gameNumber", "language", "puzzle", "createdAt")
        VALUES
        (
          \(bind: GameMode.timed),
          \(bind: 0),
          \(bind: Language.en),
          \(bind: update(ArchivablePuzzle.mock) { $0.first.first.first.left.letter = "Z" }),
          \(bind: Date(timeIntervalSince1970: 0))
        )
        RETURNING
          *,
          DATE_TRUNC('DAY', "createdAt" + INTERVAL '1 DAY') AS "endsAt"
        """
      )
      .first()
      .run.perform().unwrap()!
      .decode(model: DailyChallenge.self)

    _ = try self.database.submitLeaderboardScore(
      .init(
        dailyChallengeId: dailyChallenge.id,
        gameContext: .dailyChallenge,
        gameMode: .timed,
        language: .en,
        moves: .init(),
        playerId: player.id,
        puzzle: dailyChallenge.puzzle,
        score: 0,
        words: []
      )
    )
    .run.perform().unwrap()

    _ = try self.database.submitLeaderboardScore(
      .init(
        dailyChallengeId: oldDailyChallenge.id,
        gameContext: .dailyChallenge,
        gameMode: .timed,
        language: .en,
        moves: .init(),
        playerId: player.id,
        puzzle: dailyChallenge.puzzle,
        score: 0,
        words: []
      )
    )
    .run.perform().unwrap()

    let results = try self.database.fetchDailyChallengeResults(
      .init(
        gameMode: .timed,
        gameNumber: dailyChallenge.gameNumber,
        language: .en,
        playerId: player.id
      )
    )
    .run.perform().unwrap()

    XCTAssertNoDifference(
      results,
      [
        .init(
          isSupporter: false,
          isYourScore: true,
          outOf: 1,
          playerDisplayName: player.displayName,
          playerId: player.id,
          rank: 1,
          score: 0
        )
      ]
    )
  }

  func testTruncateAfter20() throws {
    let uuid = UUID.incrementing

    let players = try (0..<30).map { idx in
      try self.database.insertPlayer(
        update(.blob) {
          $0.deviceId = DeviceId(rawValue: uuid())
          $0.displayName = "Blob \(idx)"
          $0.gameCenterLocalPlayerId = nil
        }
      )
      .run.perform().unwrap()
    }

    try self.database.updateAppleReceipt(players[0].id, .mock)
      .run.perform().unwrap()

    let dailyChallenge = try self.database.createTodaysDailyChallenge(
      .init(
        gameMode: .unlimited,
        language: .en,
        puzzle: .mock
      )
    )
    .run.perform().unwrap()

    let scores = try players.enumerated().map { idx, player in
      try self.database.submitLeaderboardScore(
        .init(
          dailyChallengeId: dailyChallenge.id,
          gameContext: .dailyChallenge,
          gameMode: .unlimited,
          language: .en,
          moves: .init(),
          playerId: player.id,
          puzzle: dailyChallenge.puzzle,
          score: 8000 - idx * 200,
          words: []
        )
      )
      .run.perform().unwrap()
    }

    let results = try self.database.fetchDailyChallengeResults(
      .init(
        gameMode: .unlimited,
        gameNumber: nil,
        language: .en,
        playerId: players.last!.id
      )
    )
    .run.perform().unwrap()

    XCTAssertNoDifference(
      results,
      scores.enumerated()
        .map { idx, score in
          FetchDailyChallengeResultsResponse.Result(
            isSupporter: idx == 0,
            isYourScore: idx == 29,
            outOf: 30,
            playerDisplayName: "Blob \(idx)",
            playerId: score.playerId,
            rank: idx + 1,
            score: 8_000 - idx * 200
          )
        }
    )
  }
}
