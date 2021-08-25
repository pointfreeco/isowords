import CustomDump
import SnapshotTesting
import TestHelpers
import XCTest

@testable import ClientModels

class TurnBasedMatchDataTests: XCTestCase {
  func testEncodeDecode() throws {
    let uuid = UUID.incrementing

    let turnBasedMatchData = TurnBasedMatchData(
      cubes: .mock,
      gameMode: .timed,
      language: .en,
      metadata: .init(
        lastOpenedAt: .mock,
        playerIndexToId: [
          0: .init(rawValue: uuid()),
          1: .init(rawValue: uuid()),
        ]
      ),
      moves: [
        .init(
          playedAt: .mock,
          playerIndex: 0,
          reactions: [0: .angel],
          score: 200,
          type: .playedWord([])
        )
      ]
    )

    let encodedTurnBasedMatchData = try JSONEncoder().encode(turnBasedMatchData)
    let decodedTurnBasedMatchData = try JSONDecoder().decode(
      TurnBasedMatchData.self,
      from: encodedTurnBasedMatchData
    )

    XCTAssertNoDifference(decodedTurnBasedMatchData, turnBasedMatchData)

    assertSnapshot(matching: turnBasedMatchData, as: .json)
  }
}
