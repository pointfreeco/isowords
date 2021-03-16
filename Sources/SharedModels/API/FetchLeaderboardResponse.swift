import Foundation

public struct FetchLeaderboardResponse: Codable, Equatable {
  public let entries: [Entry]

  public init(
    entries: [Entry]
  ) {
    self.entries = entries
  }

  public struct Entry: Codable, Equatable {
    public let id: LeaderboardScore.Id
    public let isYourScore: Bool
    public let outOf: Int
    public let playerDisplayName: String?
    public let rank: Int
    public let score: Int

    public init(
      id: LeaderboardScore.Id,
      isYourScore: Bool,
      outOf: Int,
      playerDisplayName: String?,
      rank: Int,
      score: Int
    ) {
      self.id = id
      self.isYourScore = isYourScore
      self.outOf = outOf
      self.playerDisplayName = playerDisplayName
      self.rank = rank
      self.score = score
    }
  }
}
