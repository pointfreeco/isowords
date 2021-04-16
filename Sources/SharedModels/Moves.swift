public struct Moves:
  BidirectionalCollection,
  Codable,
  Equatable,
  ExpressibleByArrayLiteral,
  RangeReplaceableCollection
{

  var rawValue: [Move]

  public init(_ rawValue: [Move]) {
    self.rawValue = rawValue
  }

  public init() {
    self.rawValue = []
  }

  public init(arrayLiteral elements: Move...) {
    self.rawValue = elements
  }

  public var startIndex: Int {
    self.rawValue.startIndex
  }

  public var endIndex: Int {
    self.rawValue.endIndex
  }

  public subscript(position: Int) -> Move {
    self.rawValue[position]
  }

  public func index(after i: Int) -> Int {
    self.rawValue.index(after: i)
  }

  public func index(before i: Int) -> Int {
    self.rawValue.index(before: i)
  }

  mutating public func replaceSubrange<C>(
    _ subrange: Range<Int>,
    with newElements: C
  ) where C: Collection, Self.Element == C.Element {
    self.rawValue.replaceSubrange(subrange, with: newElements)
  }

  public init(from decoder: Decoder) throws {
    self.rawValue = try [Move](from: decoder)
  }

  public func encode(to encoder: Encoder) throws {
    try self.rawValue.encode(to: encoder)
  }

  public func playedWords(
    cubes: Puzzle,
    localPlayerIndex: Move.PlayerIndex?
  ) -> [PlayedWord] {
    self.reduce(into: [PlayedWord]()) {
      guard case let .playedWord(word) = $1.type else { return }
      $0.append(
        .init(
          isYourWord: $1.playerIndex == localPlayerIndex,
          reactions: $1.reactions,
          score: $1.score,
          word: cubes.string(from: word)
        )
      )
    }
  }
}
