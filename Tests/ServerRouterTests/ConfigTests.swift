import FirstPartyMocks
import Foundation
#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif
import Overture
import SharedModels
import TestHelpers
import XCTest

@testable import ServerRouter

class ConfigTests: XCTestCase {
  func testConfig() throws {
    var expectedRequest = URLRequest(
      url: URL(string: "api/config?accessToken=DEADBEEF-DEAD-BEEF-DEAD-BEEFDEADBEEF&build=42")!
    )
    expectedRequest.httpMethod = "GET"
    expectedRequest.allHTTPHeaderFields = [
      "X-Debug": "false"
    ]
    let expectedRoute = ServerRoute.api(
      .init(
        accessToken: .init(rawValue: .deadbeef),
        isDebug: false,
        route: .config(build: 42)
      )
    )

    XCTAssertEqual(
      testRouter.match(request: expectedRequest),
      expectedRoute
    )

    XCTAssertEqual(
      testRouter.request(
        for: .api(
          .init(
            accessToken: .init(rawValue: .deadbeef),
            isDebug: false,
            route: .config(build: 42)
          )
        )
      ),
      expectedRequest
    )
  }
}
