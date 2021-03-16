extension ArchivableCube {
  public static let mock = Self(left: .leftMock, right: .rightMock, top: .topMock)
}

extension ArchivableCubeFace {
  public static let leftMock = Self(letter: "A", side: .left)
  public static let rightMock = Self(letter: "B", side: .right)
  public static let topMock = Self(letter: "C", side: .top)
}

extension ArchivablePuzzle {
  public static let mock = Self(
    .init(
      .init(.mock, .mock, .mock),
      .init(.mock, .mock, .mock),
      .init(.mock, .mock, .mock)
    ),
    .init(
      .init(.mock, .mock, .mock),
      .init(.mock, .mock, .mock),
      .init(.mock, .mock, .mock)
    ),
    .init(
      .init(.mock, .mock, .mock),
      .init(.mock, .mock, .mock),
      .init(.mock, .mock, .mock)
    )
  )
}

extension Cube {
  public static let mock = Self(left: .leftMock, right: .rightMock, top: .topMock)
}

extension CubeFace {
  public static let leftMock = Self(letter: "A", side: .left)
  public static let rightMock = Self(letter: "B", side: .right)
  public static let topMock = Self(letter: "C", side: .top)
}

extension Puzzle {
  public static let mock = Self(
    .init(
      .init(.mock, .mock, .mock),
      .init(.mock, .mock, .mock),
      .init(.mock, .mock, .mock)
    ),
    .init(
      .init(.mock, .mock, .mock),
      .init(.mock, .mock, .mock),
      .init(.mock, .mock, .mock)
    ),
    .init(
      .init(.mock, .mock, .mock),
      .init(.mock, .mock, .mock),
      .init(.mock, .mock, .mock)
    )
  )
}
