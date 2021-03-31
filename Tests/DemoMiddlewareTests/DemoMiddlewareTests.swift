import DatabaseClient
import DemoMiddleware
import Either
import Foundation
#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif
import HttpPipeline
import HttpPipelineTestSupport
import Overture
import Prelude
import ServerRouter
import SharedModels
import SiteMiddleware
import SnapshotTesting
import XCTest

class DemoMiddlewareTests: XCTestCase {
  func testBasics() throws {
    var environment = Environment.unimplemented
    environment.database.fetchLeaderboardSummary = { request in
      switch request.timeScope {
      case .allTime:
        return pure(.init(outOf: 100, rank: 50))
      case .lastDay:
        return pure(.init(outOf: 20, rank: 10))
      case .lastWeek:
        return pure(.init(outOf: 50, rank: 30))
      case .interesting:
        return throwE(unit)
      }
    }

    var request = URLRequest(url: URL(string: "/demo/games")!)
    request.httpMethod = "POST"
    request.httpBody = Data(
      #"""
      {"gameMode": "timed", "score": 1000}
      """#.utf8)

    let middleware = siteMiddleware(environment: environment)
    let result = middleware(connection(from: request)).perform()

    _assertInlineSnapshot(matching: result, as: .conn, with: """
      POST /demo/games

      {"gameMode": "timed", "score": 1000}

      200 OK
      Content-Length: 211
      Content-Type: application/json
      Referrer-Policy: strict-origin-when-cross-origin
      X-Content-Type-Options: nosniff
      X-Download-Options: noopen
      X-Frame-Options: SAMEORIGIN
      X-Permitted-Cross-Domain-Policies: none
      X-XSS-Protection: 1; mode=block

      {
        "ranks" : {
          "allTime" : {
            "outOf" : 100,
            "rank" : 50
          },
          "lastDay" : {
            "outOf" : 20,
            "rank" : 10
          },
          "lastWeek" : {
            "outOf" : 50,
            "rank" : 30
          }
        }
      }
      """
    )
  }
}
