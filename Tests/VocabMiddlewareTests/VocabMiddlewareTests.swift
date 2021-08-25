import DatabaseClient
import Either
import EnvVars
import FirstPartyMocks
import Foundation
#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif
import HttpPipeline
import HttpPipelineTestSupport
import Overture
import ServerRouter
import SnapshotTesting
import XCTest

@testable import SharedModels
@testable import SiteMiddleware

class VocabMiddlewareTests: XCTestCase {
  override func setUp() {
    super.setUp()
    //    isRecording = true
  }

  func testFetchVocabWord() {
    let request = URLRequest(
      url: URL(
        string: """
          /api/leaderboard-scores/vocab/words/deadbeef-dead-beef-dead-beefdead304d?\
          accessToken=deadbeef-dead-beef-dead-beefdeadbeef
          """
      )!
    )

    var environment = ServerEnvironment.failing
    environment.database.fetchPlayerByAccessToken = { _ in pure(.blob) }
    environment.database.fetchVocabLeaderboardWord = { wordId in
      XCTAssertNoDifference(
        wordId,
        .init(rawValue: UUID(uuidString: "deadbeef-dead-beef-dead-beefdead304d")!)
      )
      return pure(
        .init(
          moveIndex: 0,
          moves: [
            .init(
              playedAt: .mock,
              playerIndex: nil,
              reactions: nil,
              score: 100,
              type: .playedWord([
                .init(index: .init(x: .zero, y: .zero, z: .zero), side: .left),
                .init(index: .init(x: .zero, y: .zero, z: .zero), side: .right),
                .init(index: .init(x: .zero, y: .zero, z: .zero), side: .top),
              ])
            )
          ],
          playerDisplayName: "Blob",
          playerId: .init(rawValue: .deadbeef),
          puzzle: .mock
        )
      )
    }

    let middleware = siteMiddleware(environment: environment)
    let result = middleware(connection(from: request)).perform()

    assertSnapshot(matching: result, as: .conn)
  }
}
