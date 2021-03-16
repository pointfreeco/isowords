import Foundation

public struct DailyChallengeHistoryResponse: Codable, Equatable {
  public var results: [Result]

  public init(
    results: [Result]
  ) {
    self.results = results
  }

  public struct Result: Codable, Equatable {
    public var createdAt: Date
    public var gameNumber: DailyChallenge.GameNumber
    public var isToday: Bool
    public var rank: Int?

    public init(
      createdAt: Date,
      gameNumber: DailyChallenge.GameNumber,
      isToday: Bool,
      rank: Int?
    ) {
      self.createdAt = createdAt
      self.gameNumber = gameNumber
      self.isToday = isToday
      self.rank = rank
    }
  }
}
