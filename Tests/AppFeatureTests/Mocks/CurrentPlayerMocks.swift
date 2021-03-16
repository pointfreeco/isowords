import Foundation

@testable import SharedModels

extension SharedModels.Player {
  static let blob = Self(
    accessToken: .init(rawValue: UUID(uuidString: "acce5500-dead-beef-dead-beefdeadbeef")!),
    createdAt: .mock,
    deviceId: .init(rawValue: UUID(uuidString: "de71ce00-dead-beef-dead-beefdeadbeef")!),
    displayName: "Blob",
    gameCenterLocalPlayerId: "_id:blob",
    id: .init(rawValue: UUID(uuidString: "b10bb10b-0000-0000-0000-000000000000")!),
    sendDailyChallengeReminder: true,
    sendDailyChallengeSummary: true,
    timeZone: "America/New York"
  )
}

extension CurrentPlayerEnvelope {
  static let mock = Self(appleReceipt: .mock, player: .blob)
}
