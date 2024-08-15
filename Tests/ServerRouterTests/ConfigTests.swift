import CustomDump
import FirstPartyMocks
import Foundation
#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif
import Overture
import SharedModels
import TestHelpers
import Parsing
import XCTest
import URLRouting

@testable import ServerRouter

class ConfigTests: XCTestCase {
  func testConfig() throws {
    var expectedRequest = URLRequest(
      url: URL(string: "/api/config?accessToken=DEADBEEF-DEAD-BEEF-DEAD-BEEFDEADBEEF&build=42")!
    )
    expectedRequest.httpMethod = "GET"
    expectedRequest.allHTTPHeaderFields = [:]
    let expectedRoute = ServerRoute.api(
      .init(
        accessToken: .init(rawValue: .deadbeef),
        isDebug: false,
        route: .config(build: 42)
      )
    )

    expectNoDifference(
      try testRouter.match(request: expectedRequest),
      expectedRoute
    )

    expectNoDifference(
      try testRouter.request(
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
