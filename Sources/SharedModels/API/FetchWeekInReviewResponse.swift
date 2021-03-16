public struct FetchWeekInReviewResponse: Codable, Equatable {
  public let ranks: [Rank]
  public let word: Word?

  public init(
    ranks: [Rank],
    word: Word?
  ) {
    self.ranks = ranks
    self.word = word
  }

  public var timedRank: Rank? {
    self.ranks.first(where: { $0.gameMode == .timed })
  }

  public var unlimitedRank: Rank? {
    self.ranks.first(where: { $0.gameMode == .unlimited })
  }

  public struct Rank: Codable, Equatable {
    public let gameMode: GameMode
    public let outOf: Int
    public let rank: Int

    public init(
      gameMode: GameMode,
      outOf: Int,
      rank: Int
    ) {
      self.gameMode = gameMode
      self.outOf = outOf
      self.rank = rank
    }
  }

  public struct Word: Codable, Equatable {
    public let letters: String
    public let score: Int

    public init(
      letters: String,
      score: Int
    ) {
      self.letters = letters
      self.score = score
    }
  }
}
