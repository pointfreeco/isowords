import NonEmpty

public struct CubeFace: Codable, Equatable {
  public var letter: NonEmptyString
  public var side: Side
  public var useCount: Int

  public init(
    letter: NonEmptyString,
    side: Side,
    useCount: Int = 0
  ) {
    self.letter = letter
    self.side = side
    self.useCount = useCount
  }

  public init(archivableCubeFaceState state: ArchivableCubeFace) {
    self.init(
      letter: state.letter,
      side: state.side,
      useCount: 0
    )
  }

  public enum Side: Int, CaseIterable, Codable, Equatable, Hashable {
    case top = 0
    case left = 1
    case right = 2
  }
}
