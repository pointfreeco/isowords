import XCTest

@testable import SharedModels

class VerificationTests: XCTestCase {
  func testWordLength() {
    var puzzle = Puzzle.mock
    puzzle.2.2.2.left.letter = "QU"
    puzzle.2.2.2.right.letter = "A"

    let result = verify(
      move: .init(
        playedAt: .init(),
        playerIndex: nil,
        reactions: nil,
        score: 10,
        type: .playedWord([
          .init(index: .init(x: .two, y: .two, z: .two), side: .left),
          .init(index: .init(x: .two, y: .two, z: .two), side: .right),
        ])
      ),
      on: &puzzle,
      isValidWord: { _ in true },
      previousMoves: []
    )

    XCTAssertEqual(
      result,
      .init(
        cubeFaces: [
          .init(index: .init(x: .two, y: .two, z: .two), side: .left),
          .init(index: .init(x: .two, y: .two, z: .two), side: .right),
        ],
        foundWord: "QUA",
        score: 10
      )
    )
  }

  func testDuplicatesNotAllowed() {
    var puzzle = Puzzle.mock
    puzzle.2.2.2.left.letter = "T"
    puzzle.2.2.2.right.letter = "O"

    let result = verify(
      move: .init(
        playedAt: .init(),
        playerIndex: nil,
        reactions: nil,
        score: 10,
        type: .playedWord([
          .init(index: .init(x: .two, y: .two, z: .two), side: .left),
          .init(index: .init(x: .two, y: .two, z: .two), side: .right),
          .init(index: .init(x: .two, y: .two, z: .two), side: .left),
        ])
      ),
      on: &puzzle,
      isValidWord: { _ in true },
      previousMoves: []
    )

    XCTAssertEqual(
      result,
      nil
    )
  }

  func testWordNotInDictionary() {
    var puzzle = Puzzle.mock
    puzzle.2.2.2.left.letter = "C"
    puzzle.2.2.2.right.letter = "A"
    puzzle.2.2.2.top.letter = "B"

    let result = verify(
      move: .init(
        playedAt: .init(),
        playerIndex: nil,
        reactions: nil,
        score: 10,
        type: .playedWord([
          .init(index: .init(x: .two, y: .two, z: .two), side: .left),
          .init(index: .init(x: .two, y: .two, z: .two), side: .right),
          .init(index: .init(x: .two, y: .two, z: .two), side: .top),
        ])
      ),
      on: &puzzle,
      isValidWord: { _ in false },
      previousMoves: []
    )

    XCTAssertEqual(
      result,
      nil
    )
  }

  func testDoubleRemove() {
    let puzzle = ArchivablePuzzle.mock

    let result = verify(
      moves: [
        .init(
          playedAt: .mock,
          playerIndex: nil,
          reactions: nil,
          score: 0,
          type: .removedCube(.init(x: .two, y: .two, z: .two))
        ),
        .init(
          playedAt: .mock,
          playerIndex: nil,
          reactions: nil,
          score: 0,
          type: .removedCube(.init(x: .two, y: .two, z: .two))
        )
      ],
      playedOn: puzzle,
      isValidWord: { _ in false }
    )

    XCTAssertNotNil(result)
  }

  func testDuplicateWord() {
    let puzzle = ArchivablePuzzle.mock

    let result = verify(
      moves: [
        .init(
          playedAt: .init(),
          playerIndex: nil,
          reactions: nil,
          score: 10,
          type: .playedWord([
            .init(index: .init(x: .two, y: .two, z: .two), side: .left),
            .init(index: .init(x: .two, y: .two, z: .two), side: .right),
            .init(index: .init(x: .two, y: .two, z: .two), side: .top),
          ])
        ),
        .init(
          playedAt: .init(),
          playerIndex: nil,
          reactions: nil,
          score: 10,
          type: .playedWord([
            .init(index: .init(x: .two, y: .two, z: .two), side: .left),
            .init(index: .init(x: .two, y: .two, z: .two), side: .right),
            .init(index: .init(x: .two, y: .two, z: .two), side: .top),
          ])
        ),
      ],
      playedOn: puzzle,
      isValidWord: { _ in false }
    )

    XCTAssertNil(result)
  }

}
