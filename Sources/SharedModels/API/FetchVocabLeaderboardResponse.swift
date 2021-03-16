public struct FetchVocabLeaderboardResponse: Codable, Equatable {
  public var entries: [Entry]

  public init(entries: [Entry]) {
    self.entries = entries
  }

  public struct Entry: Codable, Equatable {
    public let denseRank: Int
    public let isYourScore: Bool
    public let outOf: Int
    public let playerDisplayName: String?
    public let playerId: Player.Id
    public let rank: Int
    public let score: Int
    public let word: String
    public let wordId: Word.Id

    public init(
      denseRank: Int,
      isYourScore: Bool,
      outOf: Int,
      playerDisplayName: String?,
      playerId: Player.Id,
      rank: Int,
      score: Int,
      word: String,
      wordId: Word.Id
    ) {
      self.denseRank = denseRank
      self.isYourScore = isYourScore
      self.outOf = outOf
      self.playerDisplayName = playerDisplayName
      self.playerId = playerId
      self.rank = rank
      self.score = score
      self.word = word
      self.wordId = wordId
    }
  }
}
