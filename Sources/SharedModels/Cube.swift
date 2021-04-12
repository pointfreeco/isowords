import NonEmpty

public struct Cube: Codable, Equatable {
  public var left: CubeFace
  public var right: CubeFace
  public var top: CubeFace
  public var wasRemoved: Bool

  public init(
    left: CubeFace,
    right: CubeFace,
    top: CubeFace,
    wasRemoved: Bool = false
  ) {
    self.left = left
    self.right = right
    self.top = top
    self.wasRemoved = wasRemoved
  }

  public init(archivableCubeState state: ArchivableCube) {
    self.init(
      left: .init(archivableCubeFaceState: state.left),
      right: .init(archivableCubeFaceState: state.right),
      top: .init(archivableCubeFaceState: state.top)
    )
  }

  public var isInPlay: Bool {
    !self.wasRemoved
      && self.left.useCount < 3
      && self.right.useCount < 3
      && self.top.useCount < 3
  }

  public subscript(face: CubeFace.Side) -> CubeFace {
    get {
      switch face {
      case .left:
        return self.left
      case .right:
        return self.right
      case .top:
        return self.top
      }
    }
    set {
      switch newValue.side {
      case .left:
        self.left = newValue
      case .right:
        self.right = newValue
      case .top:
        self.top = newValue
      }
    }
  }
}

extension Puzzle {
  public func string(from indices: NonEmptyArray<IndexedCubeFace>) -> NonEmptyString {
    indices.map { self[$0.index][$0.side].letter }.joined()
  }

  public func isPlayable(
    side: CubeFace.Side,
    index: LatticePoint
  ) -> Bool {
    guard self[index].isInPlay else { return false }

    var start1: LatticePoint?
    var start2: LatticePoint?
    var sharedStart1: LatticePoint?
    var sharedStart2: LatticePoint?

    switch side {
    case .top:
      start1 = index + .init(x: .zero, y: .one, z: .zero)
      start2 = index + .init(x: .one, y: .one, z: .one)
      sharedStart1 = index + .init(x: .zero, y: .one, z: .one)
      sharedStart2 = index + .init(x: .one, y: .one, z: .zero)

    case .left:
      start1 = index + .init(x: .zero, y: .zero, z: .one)
      start2 = index + .init(x: .one, y: .one, z: .one)
      sharedStart1 = index + .init(x: .zero, y: .one, z: .one)
      sharedStart2 = index + .init(x: .one, y: .zero, z: .one)

    case .right:
      start1 = index + .init(x: .one, y: .zero, z: .zero)
      start2 = index + .init(x: .one, y: .one, z: .one)
      sharedStart1 = index + .init(x: .one, y: .one, z: .zero)
      sharedStart2 = index + .init(x: .one, y: .zero, z: .one)
    }

    while let next = start1 {
      defer { start1 = next + ray }
      if self[next].isInPlay {
        return false
      }
    }

    while let next = start2 {
      defer { start2 = next + ray }
      if self[next].isInPlay {
        return false
      }
    }

    while let next1 = sharedStart1, let next2 = sharedStart2 {
      defer {
        sharedStart1 = next1 + ray
        sharedStart2 = next2 + ray
      }
      if self[next1].isInPlay && self[next2].isInPlay {
        return false
      }
    }

    return true
  }
}

private let ray = LatticePoint(x: .one, y: .one, z: .one)
