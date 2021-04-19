import SharedModels
import XCTest

class SubmitGameResponseTests: XCTestCase {
  func testSubmitGameResponse_Codability_DailyChallenge() throws {
    let json: Any = [
      "dailyChallenge": [
        "outOf": 876,
        "rank": 15,
        "score": 5432,
        "started": true
      ],
      "message": "Nice job!"
    ]

    try assertBackwardsCompatibleCodable(
      value: SubmitGameResponse(
        context: .dailyChallenge(
          DailyChallengeResult(
            outOf: 876,
            rank: 15,
            score: 5432,
            started: true
          )
        ),
        message: "Nice job!"
      ),
      json: json
    )

    enum SubmitGameResponse_v1_2: Codable, Equatable {
      case dailyChallenge(DailyChallengeResult)
      case shared(SharedGameResponse)
      case solo(LeaderboardScoreResult)
      case turnBased

      init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if container.allKeys.contains(.dailyChallenge) {
          self = .dailyChallenge(
            try container.decode(DailyChallengeResult.self, forKey: .dailyChallenge))
        } else if container.allKeys.contains(.shared) {
          self = .shared(try container.decode(SharedGameResponse.self, forKey: .shared))
        } else if container.allKeys.contains(.solo) {
          self = .solo(try container.decode(LeaderboardScoreResult.self, forKey: .solo))
        } else if container.allKeys.contains(.turnBased),
          try container.decode(Bool.self, forKey: .turnBased)
        {
          self = .turnBased
        } else {
          throw
            DecodingError
            .dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Data corrupted"))
        }
      }

      func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .dailyChallenge(dailyChallengeResult):
          try container.encode(dailyChallengeResult, forKey: .dailyChallenge)
        case let .shared(sharedResult):
          try container.encode(sharedResult, forKey: .shared)
        case let .solo(leaderboardResult):
          try container.encode(leaderboardResult, forKey: .solo)
        case .turnBased:
          try container.encode(true, forKey: .turnBased)
        }
      }

      private enum CodingKeys: CodingKey {
        case dailyChallenge
        case shared
        case solo
        case turnBased
      }
    }

    try assertBackwardsCompatibleCodable(
      value: SubmitGameResponse_v1_2.dailyChallenge(
        DailyChallengeResult(
          outOf: 876,
          rank: 15,
          score: 5432,
          started: true
        )
      ),
      json: json
    )
  }

  func testSubmitGameResponse_Codability_Solo() throws {
    try assertBackwardsCompatibleCodable(
      value: SubmitGameResponse(
        context: .solo(
          LeaderboardScoreResult(
            ranks: [
              .allTime: .init(outOf: 87654, rank: 5432),
              .lastDay: .init(outOf: 876, rank: 54),
              .lastWeek: .init(outOf: 8765, rank: 543),
            ]
          )
        ),
        message: "Nice job!"
      ),
      json: [
        "message": "Nice job!",
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
      value: SubmitGameResponse(context: .turnBased, message: ""),
      json: [
        "message": "",
        "turnBased": true
      ]
    )
  }
}
