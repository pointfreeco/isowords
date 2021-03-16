import Foundation
import Tagged

public struct Player: Codable, Equatable {
  public typealias Id = Tagged<Self, UUID>

  public let accessToken: AccessToken
  public let createdAt: Date
  public let deviceId: DeviceId
  public let displayName: String?
  public let gameCenterLocalPlayerId: GameCenterLocalPlayerId?
  public let id: Id
  public let sendDailyChallengeReminder: Bool
  public let sendDailyChallengeSummary: Bool
  public let timeZone: String

  public init(
    accessToken: AccessToken,
    createdAt: Date,
    deviceId: DeviceId,
    displayName: String?,
    gameCenterLocalPlayerId: GameCenterLocalPlayerId?,
    id: Id,
    sendDailyChallengeReminder: Bool,
    sendDailyChallengeSummary: Bool,
    timeZone: String
  ) {
    self.accessToken = accessToken
    self.createdAt = createdAt
    self.deviceId = deviceId
    self.displayName = displayName
    self.gameCenterLocalPlayerId = gameCenterLocalPlayerId
    self.id = id
    self.sendDailyChallengeReminder = sendDailyChallengeReminder
    self.sendDailyChallengeSummary = sendDailyChallengeSummary
    self.timeZone = timeZone
  }
}

#if DEBUG
  extension Player {
    public static let blob = Self(
      accessToken: .init(rawValue: UUID(uuidString: "acce5500-dead-beef-dead-beefdeadbeef")!),
      createdAt: .mock,
      deviceId: .init(rawValue: UUID(uuidString: "de71ce00-dead-beef-dead-beefdeadbeef")!),
      displayName: "Blob",
      gameCenterLocalPlayerId: nil,
      id: .init(rawValue: UUID(uuidString: "b10bb10b-dead-beef-dead-beefdeadbeef")!),
      sendDailyChallengeReminder: true,
      sendDailyChallengeSummary: true,
      timeZone: "America/New_York"
    )

    public static let blobJr = Self(
      accessToken: .init(rawValue: UUID(uuidString: "acce5511-dead-beef-dead-beefdeadbeef")!),
      createdAt: .mock,
      deviceId: .init(rawValue: UUID(uuidString: "de71ce11-dead-beef-dead-beefdeadbeef")!),
      displayName: "Blob Jr.",
      gameCenterLocalPlayerId: nil,
      id: .init(rawValue: UUID(uuidString: "b10b2000-dead-beef-dead-beefdeadbeef")!),
      sendDailyChallengeReminder: true,
      sendDailyChallengeSummary: true,
      timeZone: "America/New_York"
    )

    public static let blobSr = Self(
      accessToken: .init(rawValue: UUID(uuidString: "acce5522-dead-beef-dead-beefdeadbeef")!),
      createdAt: .mock,
      deviceId: .init(rawValue: UUID(uuidString: "de71ce22-dead-beef-dead-beefdeadbeef")!),
      displayName: "Blob Sr.",
      gameCenterLocalPlayerId: nil,
      id: .init(rawValue: UUID(uuidString: "b10b0000-dead-beef-dead-beefdeadbeef")!),
      sendDailyChallengeReminder: true,
      sendDailyChallengeSummary: true,
      timeZone: "America/New_York"
    )
  }
#endif
