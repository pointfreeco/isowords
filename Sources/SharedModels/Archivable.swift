import NonEmpty

public struct ArchivableCubeFace: Codable, Equatable {
  public var letter: NonEmptyString
  public var side: CubeFace.Side

  public init(
    letter: NonEmptyString,
    side: CubeFace.Side
  ) {
    self.letter = letter
    self.side = side
  }

  public init(cubeFace: CubeFace) {
    self.letter = cubeFace.letter
    self.side = cubeFace.side
  }
}

public struct ArchivableCube: Codable, Equatable {
  public var left: ArchivableCubeFace
  public var right: ArchivableCubeFace
  public var top: ArchivableCubeFace

  public init(
    left: ArchivableCubeFace,
    right: ArchivableCubeFace,
    top: ArchivableCubeFace
  ) {
    self.left = left
    self.right = right
    self.top = top
  }

  public init(cube: Cube) {
    self.left = .init(cubeFace: cube.left)
    self.right = .init(cubeFace: cube.right)
    self.top = .init(cubeFace: cube.top)
  }

  public subscript(face: CubeFace.Side) -> ArchivableCubeFace {
    get {
      switch face {
      case .left: return self.left
      case .right: return self.right
      case .top: return self.top
      }
    }
    set {
      switch newValue.side {
      case .left: self.left = newValue
      case .right: self.right = newValue
      case .top: self.top = newValue
      }
    }
  }
}

public typealias ArchivablePuzzle = Three<Three<Three<ArchivableCube>>>

extension CubeFace {
  init(archivableCubeFace: ArchivableCubeFace) {
    self.letter = archivableCubeFace.letter
    self.side = archivableCubeFace.side
    self.useCount = 0
  }
}

extension Puzzle {
  public init(archivableCubes: ArchivablePuzzle, moves: Moves = .init()) {
    self =
      archivableCubes
      .map {
        $0.map {
          $0.map {
            Cube(
              left: .init(archivableCubeFace: $0.left),
              right: .init(archivableCubeFace: $0.right),
              top: .init(archivableCubeFace: $0.top)
            )
          }
        }
      }
    apply(moves: moves, to: &self)
  }
}

extension ArchivablePuzzle {
  public init(cubes: Puzzle) {
    self =
      cubes
      .map {
        $0.map {
          $0.map {
            ArchivableCube(
              left: .init(cubeFace: $0.left),
              right: .init(cubeFace: $0.right),
              top: .init(cubeFace: $0.top)
            )
          }
        }
      }
  }

  public func words(forMoves moves: Moves, localPlayerIndex: Move.PlayerIndex? = nil)
    -> [PlayedWord]
  {
    moves.compactMap { move in
      switch move.type {
      case let .playedWord(word):
        return .init(
          isYourWord: move.playerIndex == localPlayerIndex,
          reactions: move.reactions,
          score: move.score,
          word: self.string(from: word)
        )
      case .removedCube:
        return nil
      }
    }
  }

  public func string(from indices: NonEmptyArray<IndexedCubeFace>) -> NonEmptyString {
    indices.map { self[$0.index][$0.side].letter }.joined()
  }
}
