import CustomDump
import FirstPartyMocks
import SharedModels
import TestHelpers
import XCTest

// TODO: move tests into a compatibility test suite?
class CubeCoreTests: XCTestCase {
  func testMoveCodability() throws {
    try assertBackwardsCompatibleCodable(
      value: Move(
        playedAt: .mock,
        playerIndex: 1,
        reactions: nil,
        score: 1,
        type: .removedCube(.init(x: .zero, y: .one, z: .two))
      ),
      json: [
        "playedAt": Date.mock.timeIntervalSinceReferenceDate,
        "playerIndex": 1,
        "score": 1,
        "type": [
          "removedCube": [
            "x": 0,
            "y": 1,
            "z": 2,
          ]
        ],
      ] as [String : Any]
    )

    try assertBackwardsCompatibleCodable(
      value: Move(
        playedAt: .mock,
        playerIndex: nil,
        reactions: nil,
        score: 1,
        type: .removedCube(.init(x: .zero, y: .one, z: .two))
      ),
      json: [
        "playedAt": Date.mock.timeIntervalSinceReferenceDate,
        "score": 1,
        "type": [
          "removedCube": [
            "x": 0,
            "y": 1,
            "z": 2,
          ]
        ],
      ] as [String : Any]
    )

    try assertBackwardsCompatibleCodable(
      value: Move(
        playedAt: .mock,
        playerIndex: nil,
        reactions: nil,
        score: 1,
        type: .playedWord([
          .init(index: .zero, side: .top),
          .init(index: .zero, side: .left),
          .init(index: .zero, side: .right),
        ])
      ),
      json: [
        "playedAt": Date.mock.timeIntervalSinceReferenceDate,
        "score": 1,
        "type": [
          "playedWord": [
            ["index": ["x": 0, "y": 0, "z": 0], "side": 0],
            ["index": ["x": 0, "y": 0, "z": 0], "side": 1] as [String : Any],
            ["index": ["x": 0, "y": 0, "z": 0], "side": 2],
          ]
        ],
      ] as [String : Any]
    )
  }

  func testCubeCodability() throws {
    try assertBackwardsCompatibleCodable(
      value: Cube(
        left: .init(letter: "A", side: .left, useCount: 1),
        right: .init(letter: "B", side: .right, useCount: 2),
        top: .init(letter: "C", side: .top, useCount: 0),
        wasRemoved: false
      ),
      json: [
        "left": ["letter": "A", "side": 1, "useCount": 1] as [String : Any],
        "right": ["letter": "B", "side": 2, "useCount": 2] as [String : Any],
        "top": ["letter": "C", "side": 0, "useCount": 0] as [String : Any],
        "wasRemoved": false,
      ] as [String : Any]
    )
  }

  func testArchivableCubeCodability() throws {
    try assertBackwardsCompatibleCodable(
      value: ArchivableCube(
        left: .init(letter: "A", side: .left),
        right: .init(letter: "B", side: .right),
        top: .init(letter: "C", side: .top)
      ),
      json: [
        "left": ["letter": "A", "side": 1] as [String : Any],
        "right": ["letter": "B", "side": 2],
        "top": ["letter": "C", "side": 0],
      ]
    )
  }

  func testGameModeCodability() throws {
    try assertBackwardsCompatibleCodable(
      value: GameMode.allCases,
      json: [
        GameMode.timed.rawValue,
        GameMode.unlimited.rawValue,
      ]
    )
  }

  func testSideCodability() throws {
    try assertBackwardsCompatibleCodable(
      value: CubeFace.Side.allCases,
      json: [
        0,
        1,
        2,
      ]
    )
  }

  func testIndexedCubeFaceCodability() throws {
    try assertBackwardsCompatibleCodable(
      value: IndexedCubeFace(index: .init(x: .zero, y: .one, z: .two), side: .top),
      json: [
        "index": ["x": 0, "y": 1, "z": 2],
        "side": 0,
      ] as [String : Any]
    )
    try assertBackwardsCompatibleCodable(
      value: IndexedCubeFace(index: .init(x: .zero, y: .one, z: .two), side: .left),
      json: [
        "index": ["x": 0, "y": 1, "z": 2],
        "side": 1,
      ] as [String : Any]
    )
    try assertBackwardsCompatibleCodable(
      value: IndexedCubeFace(index: .init(x: .zero, y: .one, z: .two), side: .right),
      json: [
        "index": ["x": 0, "y": 1, "z": 2],
        "side": 2,
      ] as [String : Any]
    )
  }

  func testLatticePointCodability() throws {
    try assertBackwardsCompatibleCodable(
      value: LatticePoint(x: 0, y: 1, z: 2),
      json: [
        "x": 0, "y": 1, "z": 2,
      ]
    )
  }

  func testMoveDecoding() throws {
    let jsonDecoder = JSONDecoder()
    let jsonEncoder = JSONEncoder()

    let move = try jsonDecoder.decode(
      Move.self,
      from: Data(
        """
        {"playedAt":1234567890,"playerIndex":0,"score":0,"type":{"removedCube":{"x":1,"y":2,"z":1}}}
        """.utf8))
    expectNoDifference(move, try jsonDecoder.decode(type(of: move), from: jsonEncoder.encode(move)))
  }
}
