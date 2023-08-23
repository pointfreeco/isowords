import DatabaseClient
import DatabaseLive
import Either
import FirstPartyMocks
import Foundation
#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif
import HttpPipeline
import HttpPipelineTestSupport
import LeaderboardMiddleware
import Overture
import PostgresKit
import Prelude
import ServerRouter
import SharedModels
import SiteMiddleware
import SnapshotTesting
import XCTest

class LeaderboardMiddlewareIntegrationTests: XCTestCase {
  var database: DatabaseClient!
  let encoder = update(JSONEncoder()) {
    $0.outputFormatting = [.prettyPrinted, .sortedKeys]
  }
  let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
  var pool: EventLoopGroupConnectionPool<PostgresConnectionSource>!

  override func setUp() {
    super.setUp()
//    isRecording=true

    self.pool = EventLoopGroupConnectionPool(
      source: PostgresConnectionSource(
        configuration: PostgresConfiguration(
          url: "postgres://isowords:isowords@localhost:5432/isowords_test"
        )!
      ),
      on: self.eventLoopGroup
    )
    self.database = DatabaseClient.live(pool: self.pool)

    try! self.database.resetForTesting(pool: pool)
  }

  override func tearDown() {
    super.tearDown()

    try! self.pool.syncShutdownGracefully()
    try! self.eventLoopGroup.syncShutdownGracefully()
  }

  func testSubmitGameLeaderboardScore() throws {
    let puzzle = ArchivablePuzzle.mock
    let index = LatticePoint(x: .two, y: .two, z: .two)
    let moves: Moves = [
      Move(
        playedAt: Date(timeIntervalSince1970: 1_234_567_890),
        playerIndex: nil,
        reactions: nil,
        score: 27,
        type: .playedWord([
          .init(index: index, side: .top),
          .init(index: index, side: .left),
          .init(index: index, side: .right),
        ])
      )
    ]
    var environment = ServerEnvironment.testValue
    environment.database = self.database
    environment.dictionary = .everyString
    environment.router = .test

    let player = try self.database.insertPlayer(
      .init(
        deviceId: .init(rawValue: UUID()),
        displayName: "Blob",
        gameCenterLocalPlayerId: .init(rawValue: "id:blob"),
        timeZone: "America/New_York"
      )
    )
    .run.perform().unwrap()

    var request = URLRequest(
      url: URL(
        string:
          "/api/games?accessToken=\(player.accessToken.rawValue.uuidString)&timestamp=1234567890")!)
    request.httpMethod = "POST"
    request.httpBody = try? self.encoder.encode(
      ServerRoute.Api.Route.Games.SubmitRequest(
        gameContext: .solo(.init(gameMode: .timed, language: .en, puzzle: puzzle)),
        moves: moves
      )
    )
    request.allHTTPHeaderFields = [
      "X-Signature": (
        request.httpBody! + Data("----SECRET_DEADBEEF----1234567890".utf8)
      )
      .base64EncodedString()
    ]

    let middleware = siteMiddleware(environment: environment)
    let result = middleware(connection(from: request)).perform()

    assertSnapshot(matching: result, as: .conn)
  }
}
