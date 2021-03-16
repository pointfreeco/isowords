public struct PlayedWord: Equatable {
  public var isYourWord: Bool
  public var reactions: [Move.PlayerIndex: Move.Reaction]?
  public var score: Int
  public var word: String

  public init(
    isYourWord: Bool,
    reactions: [Move.PlayerIndex: Move.Reaction]?,
    score: Int,
    word: String
  ) {
    self.isYourWord = isYourWord
    self.reactions = reactions
    self.score = score
    self.word = word
  }

  public var orderedReactions: [Move.Reaction]? {
    self.reactions?.sorted(by: { $0.key < $1.key }).map(\.value)
  }
}
