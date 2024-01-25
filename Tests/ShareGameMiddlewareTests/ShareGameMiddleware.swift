import Either
import Foundation
#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif
import FirstPartyMocks
import HttpPipeline
import HttpPipelineTestSupport
import InlineSnapshotTesting
import Overture
import SharedModels
import TestHelpers
import XCTest

@testable import SiteMiddleware

class ShareGameMiddlewareTests: XCTestCase {
  let encoder = update(JSONEncoder()) {
    $0.outputFormatting = [.prettyPrinted, .sortedKeys]
  }

  override func setUp() {
    super.setUp()
//    isRecording = true
  }

  func testShowSharedGame() throws {
    let request = URLRequest(url: URL(string: "/sharedGames/deadbeef")!)

    let sharedGame = SharedGame(
      code: "deadbeef",
      createdAt: .mock,
      gameMode: .timed,
      id: .init(rawValue: .deadbeef),
      language: .en,
      moves: [
        .init(
          playedAt: .mock,
          playerIndex: nil,
          reactions: nil,
          score: 0,
          type: .removedCube(.zero)
        ),
        .init(
          playedAt: .mock,
          playerIndex: nil,
          reactions: nil,
          score: 10,
          type: .playedWord([
            .init(index: .zero, side: .left),
            .init(index: .zero, side: .right),
            .init(index: .zero, side: .top),
          ])
        ),
      ],
      playerId: .init(rawValue: .deadbeef),
      puzzle: .mock
    )

    let environment = update(ServerEnvironment.testValue) {
      $0.database.fetchSharedGame = { _ in pure(sharedGame) }
    }

    let middleware = siteMiddleware(environment: environment)
    let result = middleware(connection(from: request)).perform()

    assertInlineSnapshot(of: result, as: .conn) {
      """
      GET /sharedGames/deadbeef

      302 Found
      Location: isowords:///sharedGames/deadbeef
      Referrer-Policy: strict-origin-when-cross-origin
      X-Content-Type-Options: nosniff
      X-Download-Options: noopen
      X-Frame-Options: SAMEORIGIN
      X-Permitted-Cross-Domain-Policies: none
      X-XSS-Protection: 1; mode=block
      """
    }
  }

  func testFetchSharedGame() throws {
    let request = URLRequest(
      url: URL(
        string: "/api/sharedGames/deadbeef?accessToken=deadbeef-dead-beef-dead-beefdeadbeef")!)

    let sharedGame = SharedGame(
      code: "deadbeef",
      createdAt: .mock,
      gameMode: .timed,
      id: .init(rawValue: .deadbeef),
      language: .en,
      moves: [
        .init(
          playedAt: .mock,
          playerIndex: nil,
          reactions: nil,
          score: 0,
          type: .removedCube(.zero)
        ),
        .init(
          playedAt: .mock,
          playerIndex: nil,
          reactions: nil,
          score: 10,
          type: .playedWord([
            .init(index: .zero, side: .left),
            .init(index: .zero, side: .right),
            .init(index: .zero, side: .top),
          ])
        ),
      ],
      playerId: .init(rawValue: .deadbeef),
      puzzle: .mock
    )

    let environment = update(ServerEnvironment.testValue) {
      $0.database.fetchPlayerByAccessToken = { _ in pure(.blob) }
      $0.database.fetchSharedGame = { _ in pure(sharedGame) }
    }

    let middleware = siteMiddleware(environment: environment)
    let result = middleware(connection(from: request)).perform()

    assertSnapshot(matching: result, as: .conn)
  }

  func testSubmitShareGame() throws {
    var request = URLRequest(
      url: URL(string: "/api/sharedGames?accessToken=deadbeef-dead-beef-dead-beefdeadbeef")!)
    request.httpMethod = "POST"
    request.httpBody = try self.encoder.encode(
      CompletedGame(
        cubes: .mock,
        gameContext: .solo,
        gameMode: .timed,
        gameStartTime: .mock,
        language: .en,
        moves: [
          .init(
            playedAt: .mock,
            playerIndex: nil,
            reactions: nil,
            score: 0,
            type: .removedCube(.zero)
          ),
          .init(
            playedAt: .mock,
            playerIndex: nil,
            reactions: nil,
            score: 10,
            type: .playedWord([
              .init(index: .zero, side: .left),
              .init(index: .zero, side: .right),
              .init(index: .zero, side: .top),
            ])
          ),
        ],
        secondsPlayed: 0
      )
    )

    let sharedGame = SharedGame(
      code: "deadbeef",
      createdAt: .mock,
      gameMode: .timed,
      id: .init(rawValue: .deadbeef),
      language: .en,
      moves: [
        .init(
          playedAt: .mock,
          playerIndex: nil,
          reactions: nil,
          score: 0,
          type: .removedCube(.zero)
        ),
        .init(
          playedAt: .mock,
          playerIndex: nil,
          reactions: nil,
          score: 10,
          type: .playedWord([
            .init(index: .zero, side: .left),
            .init(index: .zero, side: .right),
            .init(index: .zero, side: .top),
          ])
        ),
      ],
      playerId: .init(rawValue: .deadbeef),
      puzzle: .mock
    )

    let environment = update(ServerEnvironment.testValue) {
      $0.database.fetchPlayerByAccessToken = { _ in pure(.blob) }
      $0.database.insertSharedGame = { completedGame, player in pure(sharedGame) }
    }

    let middleware = siteMiddleware(environment: environment)
    let result = middleware(connection(from: request)).perform()

    assertSnapshot(matching: result, as: .conn)
  }
}
