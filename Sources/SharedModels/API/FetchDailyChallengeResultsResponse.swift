import Foundation
import Tagged

public struct FetchDailyChallengeResultsResponse: Codable, Equatable {
  public var results: [Result]

  public init(
    results: [Result]
  ) {
    self.results = results
  }

  public struct Result: Codable, Equatable {
    public var isYourScore: Bool
    public var outOf: Int
    public var playerDisplayName: String?
    public var playerId: Player.Id
    public var rank: Int
    public var score: Int

    public init(
      isYourScore: Bool,
      outOf: Int,
      playerDisplayName: String?,
      playerId: Player.Id,
      rank: Int,
      score: Int
    ) {
      self.isYourScore = isYourScore
      self.outOf = outOf
      self.playerDisplayName = playerDisplayName
      self.playerId = playerId
      self.rank = rank
      self.score = score
    }
  }
}
