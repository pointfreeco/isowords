import AppSiteAssociationMiddleware
import Foundation
#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif
import HttpPipeline
import HttpPipelineTestSupport
import Prelude
import ServerRouter
import SharedModels
import SiteMiddleware
import SnapshotTesting
import XCTest

class AppSiteAssociationMiddlewareTests: XCTestCase {
  func testBasics() throws {
    let request = URLRequest(url: URL(string: "/.well-known/apple-app-site-association")!)
    let middleware = siteMiddleware(environment: .unimplemented)
    let result = middleware(connection(from: request)).perform()

    _assertInlineSnapshot(matching: result, as: .conn, with: #"""
      GET /.well-known/apple-app-site-association

      200 OK
      Content-Length: 433
      Content-Type: application/json
      Referrer-Policy: strict-origin-when-cross-origin
      X-Content-Type-Options: nosniff
      X-Download-Options: noopen
      X-Frame-Options: SAMEORIGIN
      X-Permitted-Cross-Domain-Policies: none
      X-XSS-Protection: 1; mode=block

      {
        "appclips" : {
          "apps" : [
            "479VDHY7L8.co.pointfree.IsoWordsTesting.Clip",
            "VFRXY8HC3H.co.pointfree.IsoWordsTesting.Clip"
          ]
        },
        "applinks" : {
          "details" : [
            {
              "appIDs" : [
                "479VDHY7L8.co.pointfree.IsoWordsTesting",
                "VFRXY8HC3H.co.pointfree.IsoWordsTesting"
              ],
              "components" : [
                {
                  "\/" : "*"
                }
              ]
            }
          ]
        }
      }
      """#)
  }
}
