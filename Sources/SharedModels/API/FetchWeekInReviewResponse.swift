public struct FetchWeekInReviewResponse: Codable, Equatable {
  public let ranks: [Rank]
  public let word: Word?
  public let foo: Bool

  public init(
    ranks: [Rank],
    word: Word?,
    foo: Bool
  ) {
    self.ranks = ranks
    self.word = word
    self.foo = foo
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
