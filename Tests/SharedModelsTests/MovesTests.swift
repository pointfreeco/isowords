import CustomDump
import Overture
import SharedModels
import SnapshotTesting
import XCTest

class MovesTests: XCTestCase {
  func testCodability() throws {
    let jsonString = """
      [{"type": {"playedWord": [{"side": 1, "index": {"x": 0, "y": 1, "z": 2}}, {"side": 1, "index": {"x": 1, "y": 1, "z": 2}}, {"side": 1, "index": {"x": 2, "y": 1, "z": 2}}]}, "score": 21, "playedAt": 623421955.818231}]
      """

    let moves = try JSONDecoder().decode(Moves.self, from: Data(jsonString.utf8))

    XCTAssertNoDifference(
      moves,
      [
        .init(
          playedAt: .init(timeIntervalSinceReferenceDate: 623421955.818231),
          playerIndex: nil,
          reactions: nil,
          score: 21,
          type: .playedWord([
            .init(index: .init(x: .zero, y: .one, z: .two), side: .left),
            .init(index: .init(x: .one, y: .one, z: .two), side: .left),
            .init(index: .init(x: .two, y: .one, z: .two), side: .left),
          ])
        )
      ]
    )
  }

  func testEncodeDecode() throws {
    let move = Move(
      playedAt: .init(timeIntervalSinceReferenceDate: 1234567890),
      playerIndex: 0,
      reactions: [
        0: .angel,
        1: .anger,
      ],
      score: 21,
      type: .playedWord([
        .init(index: .init(x: .zero, y: .one, z: .two), side: .left),
        .init(index: .init(x: .one, y: .one, z: .two), side: .left),
        .init(index: .init(x: .two, y: .one, z: .two), side: .left),
      ])
    )

    let encodedMove = try JSONEncoder().encode(move)
    let decodedMove = try JSONDecoder().decode(
      Move.self,
      from: encodedMove
    )

    XCTAssertNoDifference(decodedMove, move)

    assertSnapshot(matching: move, as: .json)
  }
}
