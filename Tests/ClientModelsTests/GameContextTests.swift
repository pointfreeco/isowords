import ClientModels
import Overture
import TestHelpers
import XCTest

class GameContextTests: XCTestCase {
  func testEncodeDecode_DailyChallenge() throws {
    let context = GameContext.dailyChallenge(.init(rawValue: .deadbeef))
    let jsonData = try jsonEncoder.encode(context)
    let json = String(decoding: jsonData, as: UTF8.self)

    XCTAssertEqual(
      json,
      """
      {
        "dailyChallengeId" : "DEADBEEF-DEAD-BEEF-DEAD-BEEFDEADBEEF"
      }
      """
    )

    let decodedContext = try JSONDecoder().decode(GameContext.self, from: jsonData)

    XCTAssertEqual(
      decodedContext,
      context
    )
  }

  func testEncodeDecode_Shared() throws {
    let context = GameContext.shared("deadbeef")
    let jsonData = try jsonEncoder.encode(context)
    let json = String(decoding: jsonData, as: UTF8.self)

    XCTAssertEqual(
      json,
      """
      {
        "sharedGameCode" : "deadbeef"
      }
      """
    )

    let decodedContext = try JSONDecoder().decode(GameContext.self, from: jsonData)

    XCTAssertEqual(
      decodedContext,
      context
    )
  }

  func testEncodeDecode_Solo() throws {
    let context = GameContext.solo
    let jsonData = try jsonEncoder.encode(context)
    let json = String(decoding: jsonData, as: UTF8.self)

    XCTAssertEqual(
      json,
      """
      {
        "solo" : true
      }
      """
    )

    let decodedContext = try JSONDecoder().decode(GameContext.self, from: jsonData)

    XCTAssertEqual(
      decodedContext,
      context
    )
  }

  func testEncodeDecode_TurnBased_PresentMatchData() throws {
    let context = GameContext.turnBased(
      .init(localPlayer: .mock, match: .mock, metadata: .init(playerIndexToId: [:], updatedAt: nil))
    )
    XCTAssertThrowsError(try jsonEncoder.encode(context))
  }

  func testEncodeDecode_DefaultsToSolor() throws {
    let jsonData = Data("{}".utf8)
    let decodedContext = try JSONDecoder().decode(GameContext.self, from: jsonData)

    XCTAssertEqual(
      decodedContext,
      .solo
    )
  }
}

let jsonEncoder = update(JSONEncoder()) {
  $0.outputFormatting = [.prettyPrinted, .sortedKeys]
}
