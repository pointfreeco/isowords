import AppSiteAssociationMiddleware
import Foundation
import HttpPipeline
import HttpPipelineTestSupport
import InlineSnapshotTesting
import Prelude
import ServerRouter
import SharedModels
import SiteMiddleware
import XCTest

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

class AppSiteAssociationMiddlewareTests: XCTestCase {
  func testBasics() throws {
    let request = URLRequest(url: URL(string: "/.well-known/apple-app-site-association")!)
    let middleware = siteMiddleware(environment: .testValue)
    let result = middleware(connection(from: request)).perform()

    assertInlineSnapshot(of: result, as: .conn) {
      #"""
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

      """#
    }
  }
}
