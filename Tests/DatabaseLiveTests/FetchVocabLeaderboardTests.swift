import XCTest

@testable import DatabaseLive
@testable import SharedModels

class FetchVocabLeaderboardTests: DatabaseTestCase {
  func testTop100() throws {
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

      _ = try self.database.submitLeaderboardScore(
        .init(
          dailyChallengeId: nil,
          gameContext: .solo,
          gameMode: .unlimited,
          language: .en,
          moves: [],
          playerId: player.id,
          puzzle: .mock,
          score: 100,
          words: [.init(moveIndex: 0, score: 100, word: "DOG")]
        )
      ).run.perform().unwrap()
    }

    let scores = try self.database.fetchVocabLeaderboard(.en, lastPlayer, .allTime)
      .run.perform().unwrap()

    XCTAssertEqual(scores.count, 110)
  }
}
