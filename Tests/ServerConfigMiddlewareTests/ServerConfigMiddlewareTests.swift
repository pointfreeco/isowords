import Either
import Foundation
#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif
import HttpPipeline
import HttpPipelineTestSupport
import SnapshotTesting
import XCTest

@testable import SharedModels
@testable import SiteMiddleware

class ServerConfigMiddlewareTests: XCTestCase {
  func testServerConfig() {
    let request = URLRequest(
      url: URL(
        string: """
          /api/config?accessToken=deadbeef-dead-beef-dead-beefdeadbeef&build=42
          """
      )!
    )

    var environment = Environment.unimplemented
    environment.database = .failing
    environment.database.fetchPlayerByAccessToken = { _ in pure(.blob) }

    let middleware = siteMiddleware(environment: environment)
    let result = middleware(connection(from: request)).perform()

    _assertInlineSnapshot(matching: result, as: .conn, with: """
      GET /api/config?accessToken=deadbeef-dead-beef-dead-beefdeadbeef&build=42

      200 OK
      Content-Length: 491
      Content-Type: application/json
      Referrer-Policy: strict-origin-when-cross-origin
      X-Content-Type-Options: nosniff
      X-Download-Options: noopen
      X-Frame-Options: SAMEORIGIN
      X-Permitted-Cross-Domain-Policies: none
      X-XSS-Protection: 1; mode=block

      {
        "appId" : "1528246952",
        "forceUpgradeVersion" : 0,
        "productIdentifiers" : {
          "fullGame" : "co.pointfree.isowords_testing.full_game"
        },
        "upgradeInterstitial" : {
          "dailyChallengeTriggerEvery" : 1,
          "duration" : 15,
          "multiplayerGameTriggerEvery" : 4,
          "nagBannerAfterInstallDuration" : 172800,
          "playedDailyChallengeGamesTriggerCount" : 2,
          "playedMultiplayerGamesTriggerCount" : 1,
          "playedSoloGamesTriggerCount" : 10,
          "soloGameTriggerEvery" : 3
        }
      }
      """
    )
  }
}
