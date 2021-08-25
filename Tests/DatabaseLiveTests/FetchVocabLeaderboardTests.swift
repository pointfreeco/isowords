import CustomDump
import XCTest

@testable import DatabaseLive
@testable import SharedModels

class FetchVocabLeaderboardTests: DatabaseTestCase {
  func testFetchVocabLeaderboard() throws {
    var puzzles = createPuzzlesIterator()

    let blob = try self.database.insertPlayer(.blob)
      .run.perform().unwrap()
    let blobJr = try self.database.insertPlayer(.blobJr)
      .run.perform().unwrap()
    try self.database.updateAppleReceipt(blob.id, .mock)
      .run.perform().unwrap()

    _ = try self.database.submitLeaderboardScore(
      .init(
        dailyChallengeId: nil,
        gameContext: .solo,
        gameMode: .timed,
        language: .en,
        moves: [],
        playerId: blob.id,
        puzzle: puzzles.next()!,
        score: 0,
        words: [
          .init(moveIndex: 0, score: 700, word: "SHRIMP"),
          .init(moveIndex: 0, score: 400, word: "MATH"),
        ]
      )
    )
    .run.perform().unwrap()

    _ = try self.database.submitLeaderboardScore(
      .init(
        dailyChallengeId: nil,
        gameContext: .solo,
        gameMode: .timed,
        language: .en,
        moves: [],
        playerId: blobJr.id,
        puzzle: puzzles.next()!,
        score: 0,
        words: [
          .init(moveIndex: 0, score: 900, word: "ZZZZ"),
          .init(moveIndex: 0, score: 1_000, word: "LOGOPHILES"),
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
        playerId: blobJr.id,
        puzzle: dailyChallengePuzzle,
        score: 1_500,
        words: [
          .init(moveIndex: 0, score: 1_000, word: "BAMBOOZLED")
        ]
      )
    )
    .run.perform().unwrap()

    let entriesSortedByScore = try self.database.fetchVocabLeaderboard(
      .en, blob, .allTime
    )
    .run.perform().unwrap()

    XCTAssertNoDifference(
      entriesSortedByScore,
      [
        .init(
          denseRank: 1,
          isSupporter: false,
          isYourScore: false,
          outOf: 5,
          playerDisplayName: "Blob Jr",
          playerId: blobJr.id,
          rank: 1,
          score: 1_000,
          word: "LOGOPHILES",
          wordId: entriesSortedByScore[0].wordId
        ),
        .init(
          denseRank: 2,
          isSupporter: false,
          isYourScore: false,
          outOf: 5,
          playerDisplayName: "Blob Jr",
          playerId: blobJr.id,
          rank: 2,
          score: 900,
          word: "ZZZZ",
          wordId: entriesSortedByScore[1].wordId
        ),
      ]
    )
  }

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
          score: 1000,
          words: [.init(moveIndex: 0, score: 1000, word: "DOG")]
        )
      ).run.perform().unwrap()
    }

    let scores = try self.database.fetchVocabLeaderboard(.en, lastPlayer, .allTime)
      .run.perform().unwrap()

    XCTAssertNoDifference(scores.count, 110)
  }
}
