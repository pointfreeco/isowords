public struct DailyChallengeResult: Codable, Equatable {
  public var outOf: Int
  public var rank: Int?
  public var score: Int?
  public var started: Bool

  public init(
    outOf: Int,
    rank: Int?,
    score: Int?,
    started: Bool = false
  ) {
    self.outOf = outOf
    self.rank = rank
    self.score = score
    self.started = started
  }
}
