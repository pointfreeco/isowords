import DatabaseClient
import Either
import EnvVars
import Foundation
#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif
import HttpPipeline
import HttpPipelineTestSupport
import LeaderboardMiddleware
import Overture
import ServerRouter
import SnapshotTesting
import XCTest

@testable import SharedModels
@testable import SiteMiddleware

class FetchWeekInReviewMiddlewareTests: XCTestCase {
  func testBasics() {
    let request = URLRequest(
      url: URL(
        string:
          "/api/leaderboard-scores/week-in-review?accessToken=deadbeef-dead-beef-dead-beefdeadbeef&language=en"
      )!
    )

    let middleware = siteMiddleware(
      environment: update(.failing) {
        $0.database.fetchPlayerByAccessToken = { _ in pure(.blob) }
        $0.database.fetchLeaderboardWeeklyRanks = { _, _ in
          pure([
            .init(gameMode: .timed, outOf: 10, rank: 9),
            .init(gameMode: .unlimited, outOf: 10, rank: 2),
          ])
        }
        $0.database.fetchLeaderboardWeeklyWord = { _, _ in
          pure(.init(letters: "GAME", score: 36))
        }
      }
    )
    let result = middleware(connection(from: request)).perform()

    assertSnapshot(matching: result, as: .conn)
  }
}
