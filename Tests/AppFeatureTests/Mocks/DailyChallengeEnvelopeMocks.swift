import Foundation
import SharedModels

extension FetchTodaysDailyChallengeResponse {
  static let unplayedChallenge = Self(
    dailyChallenge: .init(
      endsAt: Date.mock.addingTimeInterval(24 * 60 * 60),
      gameMode: .unlimited,
      id: .init(rawValue: UUID(uuidString: "deadbeef-dead-beef-dead-beefdeadbeef")!),
      language: .en
    ),
    yourResult: .init(
      outOf: 100,
      rank: nil,
      score: nil
    )
  )
}
