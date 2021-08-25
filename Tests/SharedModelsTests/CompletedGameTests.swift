import CustomDump
import FirstPartyMocks
import Overture
import SharedModels
import TestHelpers
import XCTest

class CompletedGameTests: XCTestCase {
  func testGameContext_EncodeDecode_DailyChallenge() throws {
    let context = CompletedGame.GameContext.dailyChallenge(.init(rawValue: .deadbeef))
    let jsonData = try jsonEncoder.encode(context)
    let json = String(decoding: jsonData, as: UTF8.self)

    XCTAssertNoDifference(
      json,
      """
      {
        "dailyChallengeId" : "DEADBEEF-DEAD-BEEF-DEAD-BEEFDEADBEEF"
      }
      """
    )

    let decodedContext = try JSONDecoder().decode(CompletedGame.GameContext.self, from: jsonData)

    XCTAssertNoDifference(
      decodedContext,
      context
    )
  }

  func testGameContext_EncodeDecode_Shared() throws {
    let context = CompletedGame.GameContext.shared("deadbeef")
    let jsonData = try jsonEncoder.encode(context)
    let json = String(decoding: jsonData, as: UTF8.self)

    XCTAssertNoDifference(
      json,
      """
      {
        "sharedGameCode" : "deadbeef"
      }
      """
    )

    let decodedContext = try JSONDecoder().decode(CompletedGame.GameContext.self, from: jsonData)

    XCTAssertNoDifference(
      decodedContext,
      context
    )
  }

  func testGameContext_EncodeDecode_Solo() throws {
    let context = CompletedGame.GameContext.solo
    let jsonData = try jsonEncoder.encode(context)
    let json = String(decoding: jsonData, as: UTF8.self)

    XCTAssertNoDifference(
      json,
      """
      {
        "solo" : true
      }
      """
    )

    let decodedContext = try JSONDecoder().decode(CompletedGame.GameContext.self, from: jsonData)

    XCTAssertNoDifference(
      decodedContext,
      context
    )
  }

  func testGameContext_EncodeDecode_TurnBased() throws {
    let context = CompletedGame.GameContext.turnBased(
      playerIndexToId: [0: .init(rawValue: .deadbeef)]
    )
    let jsonData = try jsonEncoder.encode(context)
    let json = String(decoding: jsonData, as: UTF8.self)

    XCTAssertNoDifference(
      json,
      """
      {
        "turnBased" : {
          "0" : "DEADBEEF-DEAD-BEEF-DEAD-BEEFDEADBEEF"
        }
      }
      """
    )

    let decodedContext = try JSONDecoder().decode(CompletedGame.GameContext.self, from: jsonData)

    XCTAssertNoDifference(
      decodedContext,
      context
    )
  }

  func testGameContext_EncodeDecode_DefaultsToSolo() throws {
    let jsonData = Data("{}".utf8)
    let decodedContext = try JSONDecoder().decode(CompletedGame.GameContext.self, from: jsonData)

    XCTAssertNoDifference(
      decodedContext,
      .solo
    )
  }
}

let jsonEncoder = update(JSONEncoder()) {
  $0.outputFormatting = [.prettyPrinted, .sortedKeys]
}
