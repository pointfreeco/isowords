import Foundation
import Tagged

public struct DailyChallengePlay: Codable, Equatable {
  public typealias Id = Tagged<Self, UUID>

  public let completedAt: Date?
  public let createdAt: Date
  public let dailyChallengeId: DailyChallenge.Id
  public let id: Id
  public let playerId: Player.Id

  public init(
    completedAt: Date?,
    createdAt: Date,
    dailyChallengeId: DailyChallenge.Id,
    id: Id,
    playerId: Player.Id
  ) {
    self.completedAt = completedAt
    self.createdAt = createdAt
    self.dailyChallengeId = dailyChallengeId
    self.id = id
    self.playerId = playerId
  }
}
