import Foundation
import Tagged

public struct Word: Codable, Equatable {
  public typealias Id = Tagged<Self, UUID>

  public let createdAt: Date
  public let id: Id
  public let leaderboardScoreId: LeaderboardScore.Id
  public let moveIndex: Int
  public let score: Int
  public let word: String
}
