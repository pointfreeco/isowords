import CustomDump
import XCTest

@testable import DatabaseLive
@testable import SharedModels

class FetchWeekInReviewTests: DatabaseTestCase {
  func testWeekInReview() throws {
    var puzzles = createPuzzlesIterator()
    let uuids = UUID.incrementing

    var lastPlayer: Player!

    try (1...110).forEach { idx in
      let player = try self.database.insertPlayer(
        .init(
          deviceId: .init(rawValue: uuids()),
          displayName: "Blob\(idx)",
          gameCenterLocalPlayerId: .init(rawValue: "id:blob\(idx)"),
          timeZone: "America/New_York"
        )
      ).run.perform().unwrap()
      lastPlayer = player

      if idx % 9 != 0 {
        _ = try self.database.submitLeaderboardScore(
          .init(
            dailyChallengeId: nil,
            gameContext: .solo,
            gameMode: .unlimited,
            language: .en,
            moves: [],
            playerId: player.id,
            puzzle: puzzles.next()!,
            score: 100 * idx,
            words: [.init(moveIndex: 0, score: 100 * idx, word: "DOGGO")]
          )
        ).run.perform().unwrap()
      }
      if idx % 7 != 0 {
        _ = try self.database.submitLeaderboardScore(
          .init(
            dailyChallengeId: nil,
            gameContext: .solo,
            gameMode: .timed,
            language: .en,
            moves: [],
            playerId: player.id,
            puzzle: puzzles.next()!,
            score: 100 * (110 - idx),
            words: [.init(moveIndex: 0, score: 100 * (110 - idx), word: "DOG")]
          )
        ).run.perform().unwrap()
      }
    }

    // Don't include turn-based
    _ = try self.database.submitLeaderboardScore(
      .init(
        dailyChallengeId: nil,
        gameContext: .turnBased,
        gameMode: .unlimited,
        language: .en,
        moves: [],
        playerId: lastPlayer.id,
        puzzle: puzzles.next()!,
        score: 100,
        words: [.init(moveIndex: 0, score: 100, word: "CAT")]
      )
    ).run.perform().unwrap()

    // Don't include today's challenge
    let dailyChallenge = try self.database.createTodaysDailyChallenge(
      .init(
        gameMode: .timed,
        language: .en,
        puzzle: .mock
      )
    )
    .run.perform().unwrap()
    _ = try self.database.submitLeaderboardScore(
      .init(
        dailyChallengeId: dailyChallenge.id,
        gameContext: .dailyChallenge,
        gameMode: .unlimited,
        language: .en,
        moves: [],
        playerId: lastPlayer.id,
        puzzle: puzzles.next()!,
        score: 12000,
        words: [.init(moveIndex: 0, score: 100, word: "CAT")]
      )
    ).run.perform().unwrap()

    let ranks = try self.database.fetchLeaderboardWeeklyRanks(.en, lastPlayer)
      .run.perform().unwrap()
    expectNoDifference(
      [
        .init(gameMode: .timed, outOf: 95, rank: 95),
        .init(gameMode: .unlimited, outOf: 98, rank: 1),
      ],
      ranks
    )

    let word = try self.database.fetchLeaderboardWeeklyWord(.en, lastPlayer)
      .run.perform().unwrap()
    expectNoDifference(word, .init(letters: "DOGGO", score: 11000))
  }
}
