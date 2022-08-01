import DatabaseClient
import Either
import Foundation
#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif
import HttpPipeline
import SnapshotTesting
import XCTest

@testable import SharedModels
@testable import SiteMiddleware

class CurrentPlayerMiddlewareTests: XCTestCase {
  override func setUp() {
    super.setUp()
//    isRecording=true
  }

  func testCurrentPlayer() {
    let request = URLRequest(
      url: URL(
        string: "/api/current-player?accessToken=deadbeef-dead-beef-dead-beefdeadbeef"
      )!
    )

    var environment = ServerEnvironment.unimplemented
    environment.database.fetchAppleReceipt = { _ in pure(.mock) }
    environment.database.fetchPlayerByAccessToken = { _ in pure(.blob) }

    let middleware = siteMiddleware(environment: environment)
    let result = middleware(connection(from: request)).perform()

    assertSnapshot(matching: result, as: .conn)
  }
}
