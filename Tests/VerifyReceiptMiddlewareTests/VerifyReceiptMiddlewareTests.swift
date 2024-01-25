import CustomDump
import Either
import Foundation
#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif
import EnvVars
import Foundation
import HttpPipeline
import HttpPipelineTestSupport
import Overture
import SharedModels
import SnapshotTesting
import XCTest

@testable import SiteMiddleware

class VerifyReceiptMiddlewareTests: XCTestCase {
  let encoder = update(JSONEncoder()) {
    $0.outputFormatting = [.prettyPrinted, .sortedKeys]
  }

  override func setUp() {
    super.setUp()
//    isRecording=true
  }
  
  func testHappyPath() {
    var updatedPlayerId: Player.Id?
    var updatedAppleResponse: AppleVerifyReceiptResponse?

    let environment = update(ServerEnvironment.testValue) {
      $0.database.fetchPlayerByAccessToken = { _ in
        pure(.blob)
      }
      $0.itunes.verify = { data, environment in
        switch environment {
        case .sandbox: fatalError()
        case .production: return pure((.fullGame, data))
        }
      }
      $0.database.updateAppleReceipt = {
        updatedPlayerId = $0
        updatedAppleResponse = $1
        return pure(())
      }
    }

    let middleware = siteMiddleware(environment: environment)

    var request = URLRequest(
      url: URL(
        string: "/api/verify-receipt?accessToken=deadbeef-dead-beef-dead-beefdeadbeef"
      )!
    )
    request.httpMethod = "POST"
    request.httpBody = try? self.encoder.encode(AppleVerifyReceiptResponse.mock)
    let result = middleware(connection(from: request)).perform()

    _assertInlineSnapshot(matching: result, as: .conn, with: """
      POST /api/verify-receipt?accessToken=deadbeef-dead-beef-dead-beefdeadbeef
      
      {
        "environment" : "Production",
        "is-retryable" : true,
        "receipt" : {
          "app_item_id" : 1,
          "application_version" : "1",
          "bundle_id" : "co.pointfree.isowords",
          "in_app" : [
            {
              "original_purchase_date_ms" : "2212875090000",
              "original_transaction_id" : "deadbeef",
              "product_id" : "full-game",
              "purchase_date_ms" : "2212875090000",
              "quantity" : "1",
              "transaction_id" : "deadbeef"
            }
          ],
          "original_purchase_date_ms" : "2212875090000",
          "receipt_creation_date_ms" : "2212875090000",
          "request_date_ms" : "2212875090000"
        },
        "status" : 0
      }
      
      200 OK
      Content-Length: 63
      Content-Type: application/json
      Referrer-Policy: strict-origin-when-cross-origin
      X-Content-Type-Options: nosniff
      X-Download-Options: noopen
      X-Frame-Options: SAMEORIGIN
      X-Permitted-Cross-Domain-Policies: none
      X-XSS-Protection: 1; mode=block
      
      {
        "verifiedProductIds" : [
          "co.pointfree.full_game"
        ]
      }
      """
    )

    XCTAssertNoDifference(
      updatedPlayerId,
      .init(rawValue: UUID(uuidString: "b10bb10b-dead-beef-dead-beefdeadbeef")!)
    )
    XCTAssertNoDifference(
      updatedAppleResponse,
      .some(.mock)
    )
  }

  func testSandboxFallback_FailedRequest() {
    var updatedPlayerId: Player.Id?
    var updatedData: AppleVerifyReceiptResponse?

    let environment = update(ServerEnvironment.testValue) {
      $0.database.fetchPlayerByAccessToken = { _ in
        pure(.blob)
      }
      $0.itunes.verify = { data, environment in
        environment == .sandbox
          ? pure((.fullGame, data))
          : throwE(URLError.init(.badServerResponse))
      }
      $0.database.updateAppleReceipt = {
        updatedPlayerId = $0
        updatedData = $1
        return pure(())
      }
    }

    let middleware = siteMiddleware(environment: environment)

    var request = URLRequest(
      url: URL(
        string: "/api/verify-receipt?accessToken=deadbeef-dead-beef-dead-beefdeadbeef"
      )!
    )
    request.httpMethod = "POST"
    request.httpBody = try? self.encoder.encode(AppleVerifyReceiptResponse.mock)
    let result = middleware(connection(from: request)).perform()

    _assertInlineSnapshot(matching: result, as: .conn, with: """
      POST /api/verify-receipt?accessToken=deadbeef-dead-beef-dead-beefdeadbeef
      
      {
        "environment" : "Production",
        "is-retryable" : true,
        "receipt" : {
          "app_item_id" : 1,
          "application_version" : "1",
          "bundle_id" : "co.pointfree.isowords",
          "in_app" : [
            {
              "original_purchase_date_ms" : "2212875090000",
              "original_transaction_id" : "deadbeef",
              "product_id" : "full-game",
              "purchase_date_ms" : "2212875090000",
              "quantity" : "1",
              "transaction_id" : "deadbeef"
            }
          ],
          "original_purchase_date_ms" : "2212875090000",
          "receipt_creation_date_ms" : "2212875090000",
          "request_date_ms" : "2212875090000"
        },
        "status" : 0
      }
      
      200 OK
      Content-Length: 63
      Content-Type: application/json
      Referrer-Policy: strict-origin-when-cross-origin
      X-Content-Type-Options: nosniff
      X-Download-Options: noopen
      X-Frame-Options: SAMEORIGIN
      X-Permitted-Cross-Domain-Policies: none
      X-XSS-Protection: 1; mode=block
      
      {
        "verifiedProductIds" : [
          "co.pointfree.full_game"
        ]
      }
      """
    )

    XCTAssertNoDifference(
      updatedPlayerId,
      .init(rawValue: UUID(uuidString: "b10bb10b-dead-beef-dead-beefdeadbeef")!)
    )
    XCTAssertNoDifference(
      updatedData,
      .some(.mock)
    )
  }

  func testSandboxFallback_BadStatus() {
    var updatedPlayerId: Player.Id?
    var updatedData: AppleVerifyReceiptResponse?

    let middleware = siteMiddleware(
      environment: update(.testValue) {
        $0.database.fetchPlayerByAccessToken = { _ in pure(.blob) }
        $0.itunes.verify = { data, environment in
          environment == .sandbox
            ? pure((.fullGame, data))
            : pure((update(.fullGame, mut(\.status, 1)), data))
        }
        $0.database.updateAppleReceipt = {
          updatedPlayerId = $0
          updatedData = $1
          return pure(())
        }
      }
    )

    var request = URLRequest(
      url: URL(
        string: "/api/verify-receipt?accessToken=deadbeef-dead-beef-dead-beefdeadbeef"
      )!
    )
    request.httpMethod = "POST"
    request.httpBody = try? self.encoder.encode(AppleVerifyReceiptResponse.mock)
    let result = middleware(connection(from: request)).perform()

    _assertInlineSnapshot(matching: result, as: .conn, with: """
      POST /api/verify-receipt?accessToken=deadbeef-dead-beef-dead-beefdeadbeef
      
      {
        "environment" : "Production",
        "is-retryable" : true,
        "receipt" : {
          "app_item_id" : 1,
          "application_version" : "1",
          "bundle_id" : "co.pointfree.isowords",
          "in_app" : [
            {
              "original_purchase_date_ms" : "2212875090000",
              "original_transaction_id" : "deadbeef",
              "product_id" : "full-game",
              "purchase_date_ms" : "2212875090000",
              "quantity" : "1",
              "transaction_id" : "deadbeef"
            }
          ],
          "original_purchase_date_ms" : "2212875090000",
          "receipt_creation_date_ms" : "2212875090000",
          "request_date_ms" : "2212875090000"
        },
        "status" : 0
      }
      
      200 OK
      Content-Length: 63
      Content-Type: application/json
      Referrer-Policy: strict-origin-when-cross-origin
      X-Content-Type-Options: nosniff
      X-Download-Options: noopen
      X-Frame-Options: SAMEORIGIN
      X-Permitted-Cross-Domain-Policies: none
      X-XSS-Protection: 1; mode=block
      
      {
        "verifiedProductIds" : [
          "co.pointfree.full_game"
        ]
      }
      """
    )

    XCTAssertNoDifference(
      updatedPlayerId,
      .init(rawValue: UUID(uuidString: "b10bb10b-dead-beef-dead-beefdeadbeef")!)
    )
    XCTAssertNoDifference(
      updatedData,
      .some(.mock)
    )
  }
}
