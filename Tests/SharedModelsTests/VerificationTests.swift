import CustomDump
import XCTest

@testable import SharedModels

class VerificationTests: XCTestCase {
  func testWordLength() {
    var puzzle = ArchivablePuzzle.mock
    puzzle.2.2.2.left.letter = "QU"
    puzzle.2.2.2.right.letter = "A"

    let result = verify(
      moves: [
        .init(
          playedAt: .init(),
          playerIndex: nil,
          reactions: nil,
          score: 42,
          type: .playedWord([
            .init(index: .init(x: .two, y: .two, z: .two), side: .left),
            .init(index: .init(x: .two, y: .two, z: .two), side: .right),
          ])
        )
      ],
      playedOn: puzzle,
      isValidWord: { _ in true }
    )

    XCTAssertNoDifference(
      result,
      .init(
        totalScore: 42,
        verifiedMoves: [
          .init(
            cubeFaces: [
              .init(index: .init(x: .two, y: .two, z: .two), side: .left),
              .init(index: .init(x: .two, y: .two, z: .two), side: .right),
            ],
            foundWord: "QUA",
            score: 42
          )
        ]
      )
    )
  }

  func testDuplicateCubeFacesNotAllowed() {
    var puzzle = ArchivablePuzzle.mock
    puzzle.2.2.2.left.letter = "T"
    puzzle.2.2.2.right.letter = "O"

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
            .init(index: .init(x: .two, y: .two, z: .two), side: .left),
          ])
        )
      ],
      playedOn: puzzle,
      isValidWord: { _ in true }
    )

    XCTAssertNoDifference(
      result,
      nil
    )
  }

  func testWordNotInDictionary() {
    var puzzle = ArchivablePuzzle.mock
    puzzle.2.2.2.left.letter = "C"
    puzzle.2.2.2.right.letter = "A"
    puzzle.2.2.2.top.letter = "B"

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
        )
      ],
      playedOn: puzzle,
      isValidWord: { _ in false }
    )

    XCTAssertNoDifference(
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

  func testUseSameWordTwiceIsNotAllowed() {
    let puzzle = ArchivablePuzzle.mock

    let result = verify(
      moves: [
        .init(
          playedAt: . mock,
          playerIndex: nil,
          reactions: nil,
          score: score("CAB"),
          type: .playedWord([
            .init(index: .init(x: .two, y: .two, z: .two), side: .top),
            .init(index: .init(x: .two, y: .two, z: .two), side: .left),
            .init(index: .init(x: .two, y: .two, z: .two), side: .right),
          ])
        ),
        .init(
          playedAt: . mock,
          playerIndex: nil,
          reactions: nil,
          score: score("CAB"),
          type: .playedWord([
            .init(index: .init(x: .two, y: .two, z: .two), side: .top),
            .init(index: .init(x: .two, y: .two, z: .two), side: .left),
            .init(index: .init(x: .two, y: .two, z: .two), side: .right),
          ])
        )
      ],
      playedOn: puzzle,
      isValidWord: { _ in true }
    )

    XCTAssertNoDifference(result, nil)
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
