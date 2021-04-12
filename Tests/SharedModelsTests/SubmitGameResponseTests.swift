import SharedModels
import XCTest

class SubmitGameResponseTests: XCTestCase {
  func testSubmitGameResponse_Codability_DailyChallenge() throws {
    try assertBackwardsCompatibleCodable(
      value: SubmitGameResponse.dailyChallenge(
        DailyChallengeResult(
          outOf: 876,
          rank: 15,
          score: 5432,
          started: true
        )
      ),
      json: [
        "dailyChallenge": [
          "outOf": 876,
          "rank": 15,
          "score": 5432,
          "started": true
        ]
      ]
    )
  }

  func testSubmitGameResponse_Codability_Solo() throws {
    try assertBackwardsCompatibleCodable(
      value: SubmitGameResponse.solo(
        LeaderboardScoreResult(
          ranks: [
            .allTime: .init(outOf: 87654, rank: 5432),
            .lastDay: .init(outOf: 876, rank: 54),
            .lastWeek: .init(outOf: 8765, rank: 543),
          ]
        )
      ),
      json: [
        "solo": [
          "ranks": [
            "allTime": ["outOf": 87654, "rank": 5432],
            "lastDay": ["outOf": 876, "rank": 54],
            "lastWeek": ["outOf": 8765, "rank": 543],
          ]
        ]
      ]
    )
  }

  func testSubmitGameResponse_Codability_TurnBased() throws {
    try assertBackwardsCompatibleCodable(
      value: SubmitGameResponse.turnBased,
      json: [
        "turnBased": true
      ]
    )
  }
}
