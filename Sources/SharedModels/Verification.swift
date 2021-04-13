public struct VerifiedPuzzleResult {
  public var totalScore = 0
  public var verifiedMoves: [VerifiedMoveResult] = []
}

public struct VerifiedMoveResult: Equatable {
  public let cubeFaces: [IndexedCubeFace]
  public let foundWord: String?
  public let score: Int
}

public func verify(
  moves: Moves,
  playedOn puzzle: ArchivablePuzzle,
  isValidWord: (String) -> Bool
) -> VerifiedPuzzleResult? {
  var puzzle = Puzzle(archivableCubes: puzzle)

  var result = VerifiedPuzzleResult()
  for index in moves.indices {
    if let moveResult = verify(
      move: moves[index],
      on: &puzzle,
      isValidWord: isValidWord,
      previousMoves: .init(moves[..<index])
    ) {
      result.totalScore += moveResult.score
      result.verifiedMoves.append(moveResult)
    } else {
      return nil
    }
  }

  // TODO: validate score passed to API
  return result
}

public func verify(
  move: Move,
  on puzzle: inout Puzzle,
  isValidWord: (String) -> Bool,
  previousMoves: Moves
) -> VerifiedMoveResult? {
  switch move.type {
  case let .playedWord(cubeFaces):
    guard cubeFaces.count == Set(cubeFaces).count
    else { return nil }

    let foundWord = puzzle.string(from: cubeFaces)

    let isValidMove =
      foundWord.count >= 3
      && previousMoves.allSatisfy {
        guard case let .playedWord(faces) = $0.type else { return true }
        return puzzle.string(from: faces) != foundWord
      }
      && zip(cubeFaces.dropFirst(), cubeFaces)
        .reduce(true) { accum, faces in
          let (next, previous) = faces
          return accum
            && next.isTouching(previous)
            && puzzle.isPlayable(side: next.side, index: next.index)
            && puzzle[next.index].isInPlay
            && puzzle[previous.index].isInPlay
        }

    if isValidMove && isValidWord(foundWord) {
      apply(move: move, to: &puzzle)
      // TODO: this score should be computed from the string rather than using what is handed us.
      //       in fact maybe we need an ArchivableMove to remove that info?
      return .init(cubeFaces: cubeFaces, foundWord: foundWord, score: move.score)
    } else {
      return nil
    }

  case let .removedCube(point):
    if puzzle[point].isInPlay
      // NB: Allow "removing" an out of play cube if it was removed in the previous move. This
      //     is to work around a race condition in the client where quickly tapping multiple times
      //     can accidentally remove a single cube twice.
      || previousMoves.last?.type == move.type
    {
      apply(move: move, to: &puzzle)
      return .init(cubeFaces: [], foundWord: nil, score: 0)
    } else {
      return nil
    }
  }
}

public func apply<Moves>(
  moves: Moves,
  to puzzle: inout Puzzle
) where Moves: Collection, Moves.Element == Move {
  for move in moves {
    apply(move: move, to: &puzzle)
  }
}

public func apply(
  move: Move,
  to puzzle: inout Puzzle
) {
  switch move.type {
  case let .playedWord(cubeFaces):
    for cubeFace in cubeFaces {
      puzzle[cubeFace.index][cubeFace.side].useCount += 1
    }

  case let .removedCube(index):
    puzzle[index].wasRemoved = true
  }
}
