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
          .init(moveIndex: 0, score: 100, word: "SHRIMP"),
          .init(moveIndex: 0, score: 20, word: "MATH"),
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
        playerId: blobJr.id,
        puzzle: dailyChallengePuzzle,
        score: 1_000,
        words: [
          .init(moveIndex: 0, score: 1_000, word: "BAMBOOZLED")
        ]
      )
    )
    .run.perform().unwrap()

    let entriesSortedByScore = try self.database.fetchVocabLeaderboard(
      .en, blob, .allTime, .score
    )
    .run.perform().unwrap()

    XCTAssertEqual(
      entriesSortedByScore,
      [
        .init(
          denseRank: 1,
          isSupporter: false,
          isYourScore: false,
          outOf: 4,
          playerDisplayName: "Blob Jr",
          playerId: blobJr.id,
          rank: 1,
          score: 500,
          word: "LOGOPHILES",
          wordId: entriesSortedByScore[0].wordId
        ),
        .init(
          denseRank: 2,
          isSupporter: false,
          isYourScore: false,
          outOf: 4,
          playerDisplayName: "Blob Jr",
          playerId: blobJr.id,
          rank: 2,
          score: 150,
          word: "ZZZZ",
          wordId: entriesSortedByScore[1].wordId
        ),
        .init(
          denseRank: 3,
          isSupporter: true,
          isYourScore: true,
          outOf: 4,
          playerDisplayName: "Blob",
          playerId: blob.id,
          rank: 3,
          score: 100,
          word: "SHRIMP",
          wordId: entriesSortedByScore[2].wordId
        ),
        .init(
          denseRank: 4,
          isSupporter: true,
          isYourScore: true,
          outOf: 4,
          playerDisplayName: "Blob",
          playerId: blob.id,
          rank: 4,
          score: 20,
          word: "MATH",
          wordId: entriesSortedByScore[3].wordId
        ),
      ]
    )

    let entriesSortedByLength = try self.database.fetchVocabLeaderboard(
      .en, blob, .allTime, .length
    )
    .run.perform().unwrap()

    XCTAssertEqual(
      entriesSortedByLength,
      [
        .init(
          denseRank: 1,
          isSupporter: false,
          isYourScore: false,
          outOf: 4,
          playerDisplayName: "Blob Jr",
          playerId: blobJr.id,
          rank: 1,
          score: 500,
          word: "LOGOPHILES",
          wordId: entriesSortedByLength[0].wordId
        ),
        .init(
          denseRank: 2,
          isSupporter: true,
          isYourScore: true,
          outOf: 4,
          playerDisplayName: "Blob",
          playerId: blob.id,
          rank: 2,
          score: 100,
          word: "SHRIMP",
          wordId: entriesSortedByLength[1].wordId
        ),
        .init(
          denseRank: 3,
          isSupporter: true,
          isYourScore: true,
          outOf: 4,
          playerDisplayName: "Blob",
          playerId: blob.id,
          rank: 3,
          score: 20,
          word: "MATH",
          wordId: entriesSortedByLength[2].wordId
        ),
        .init(
          denseRank: 3,
          isSupporter: false,
          isYourScore: false,
          outOf: 4,
          playerDisplayName: "Blob Jr",
          playerId: blobJr.id,
          rank: 3,
          score: 150,
          word: "ZZZZ",
          wordId: entriesSortedByLength[3].wordId
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
          score: 100,
          words: [.init(moveIndex: 0, score: 100, word: "DOG")]
        )
      ).run.perform().unwrap()
    }

    let scores = try self.database.fetchVocabLeaderboard(.en, lastPlayer, .allTime, .score)
      .run.perform().unwrap()

    XCTAssertEqual(scores.count, 110)
  }

//  func testTop100() throws {
//    let blob = try self.database.insertPlayer(
//      .init(
//        deviceId: .init(rawValue: UUID()),
//        displayName: "Blob",
//        gameCenterLocalPlayerId: "id:blob",
//        timeZone: "America/New_York"
//      )
//    )
//    .run.perform().unwrap()
//
//    try self.database.updateAppleReceipt(blob.id, .mock)
//      .run.perform().unwrap()
//
//    let blobJr = try self.database.insertPlayer(
//      .init(
//        deviceId: .init(rawValue: UUID()),
//        displayName: "Blob Jr",
//        gameCenterLocalPlayerId: "id:blob-jr",
//        timeZone: "America/Los_Angeles"
//      )
//    )
//    .run.perform().unwrap()
//
//    _ = try self.database.submitLeaderboardScore(
//      .init(
//        dailyChallengeId: nil,
//        gameContext: .solo,
//        gameMode: .timed,
//        language: .en,
//        moves: [],
//        playerId: blob.id,
//        puzzle: .mock,
//        score: 110,
//        words: [
//          .init(
//            moveIndex: 0,
//            score: 60,
//            word: "DOG"
//          ),
//          .init(
//            moveIndex: 0,
//            score: 50,
//            word: "CAT"
//          ),
//        ]
//      )
//    )
//    .run.perform().unwrap()
//
//    _ = try self.database.submitLeaderboardScore(
//      .init(
//        dailyChallengeId: nil,
//        gameContext: .solo,
//        gameMode: .timed,
//        language: .en,
//        moves: [],
//        playerId: blobJr.id,
//        puzzle: .mock,
//        score: 200,
//        words: [
//          .init(
//            moveIndex: 0,
//            score: 150,
//            word: "DOGGY"
//          ),
//          .init(
//            moveIndex: 0,
//            score: 50,
//            word: "CAT"
//          ),
//        ]
//      )
//    )
//    .run.perform().unwrap()
//
//
//    let scores = try self.database.fetchVocabLeaderboard(.en, blob, .allTime, .score)
//      .run.perform().unwrap()
//
//    XCTAssertEqual(
//      scores,
//      [
//        .init(
//          denseRank: 1,
//          isSupporter: false,
//          isYourScore: false,
//          outOf: 4,
//          playerDisplayName: "Blob Jr",
//          playerId: blobJr.id,
//          rank: 1,
//          score: 150,
//          word: "DOGGY",
//          wordId: .init(rawValue: UUID(uuidString: "00000000-0000-0000-0000-000000000010")!)
//        ),
//        .init(
//          denseRank: 2,
//          isSupporter: true,
//          isYourScore: true,
//          outOf: 4,
//          playerDisplayName: "Blob",
//          playerId: blob.id,
//          rank: 2,
//          score: 60,
//          word: "DOG",
//          wordId: .init(rawValue: UUID(uuidString: "00000000-0000-0000-0000-000000000007")!)
//        ),
//        .init(
//          denseRank: 3,
//          isSupporter: true,
//          isYourScore: true,
//          outOf: 4,
//          playerDisplayName: "Blob",
//          playerId: blob.id,
//          rank: 3,
//          score: 50,
//          word: "CAT",
//          wordId: .init(rawValue: UUID(uuidString: "00000000-0000-0000-0000-000000000008")!)
//        ),
//        .init(
//          denseRank: 3,
//          isSupporter: false,
//          isYourScore: false,
//          outOf: 4,
//          playerDisplayName: "Blob Jr",
//          playerId: blobJr.id,
//          rank: 3,
//          score: 50,
//          word: "CAT",
//          wordId: .init(rawValue: UUID(uuidString: "00000000-0000-0000-0000-000000000011")!)
//        ),
//      ]
//    )
//  }
}
