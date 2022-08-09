import DatabaseClient
import Either
import EnvVars
import Foundation
#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif
import HttpPipeline
import HttpPipelineTestSupport
import Overture
import ServerRouter
import SharedModels
import SnapshotTesting
import XCTest

@testable import SiteMiddleware

class AuthenticationMiddlewareTests: XCTestCase {
  override func setUp() {
    super.setUp()
//    isRecording=true
  }

  func testRegister_WithGameCenterId() throws {
    var request = URLRequest(url: URL(string: "/api/authenticate")!)
    request.httpMethod = "POST"
    request.httpBody = Data(
      """
      {
        "deviceId": "de71ce00-dead-beef-dead-beefdeadbeef",
        "displayName": "Blob",
        "gameCenterLocalPlayerId": "_id:blob"
      }
      """.utf8)

    var environment = ServerEnvironment.unimplemented
    environment.database.fetchAppleReceipt = { _ in pure(.mock) }
    environment.database.insertPlayer = { request in
      pure(
        Player(
          accessToken: .init(rawValue: UUID(uuidString: "acce5500-dead-beef-dead-beefdeadbeef")!),
          createdAt: Date(timeIntervalSince1970: 1_234_567_890),
          deviceId: request.deviceId,
          displayName: request.displayName,
          gameCenterLocalPlayerId: request.gameCenterLocalPlayerId,
          id: .init(rawValue: UUID(uuidString: "deadbeef-dead-beef-dead-beefdeadbeef")!),
          sendDailyChallengeReminder: true,
          sendDailyChallengeSummary: true,
          timeZone: "America/New_York"
        )
      )
    }
    environment.database.fetchPlayerByDeviceId = { _ in pure(nil) }
    environment.database.fetchPlayerByGameCenterLocalPlayerId = { _ in pure(nil) }

    let middleware = siteMiddleware(environment: environment)
    let result = middleware(connection(from: request)).perform()

    _assertInlineSnapshot(matching: result, as: .conn, with: #"""
      POST /api/authenticate

      {
        "deviceId": "de71ce00-dead-beef-dead-beefdeadbeef",
        "displayName": "Blob",
        "gameCenterLocalPlayerId": "_id:blob"
      }

      200 OK
      Content-Length: 1099
      Content-Type: application/json
      Referrer-Policy: strict-origin-when-cross-origin
      X-Content-Type-Options: nosniff
      X-Download-Options: noopen
      X-Frame-Options: SAMEORIGIN
      X-Permitted-Cross-Domain-Policies: none
      X-XSS-Protection: 1; mode=block

      {
        "appleReceipt" : {
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
        },
        "player" : {
          "accessToken" : "ACCE5500-DEAD-BEEF-DEAD-BEEFDEADBEEF",
          "createdAt" : 256260690,
          "deviceId" : "DE71CE00-DEAD-BEEF-DEAD-BEEFDEADBEEF",
          "displayName" : "Blob",
          "gameCenterLocalPlayerId" : "_id:blob",
          "id" : "DEADBEEF-DEAD-BEEF-DEAD-BEEFDEADBEEF",
          "sendDailyChallengeReminder" : true,
          "sendDailyChallengeSummary" : true,
          "timeZone" : "America\/New_York"
        }
      }
      """#
    )
  }

  func testRegister_WithInvalidGameCenterId() throws {
    var request = URLRequest(url: URL(string: "/api/authenticate")!)
    request.httpMethod = "POST"
    request.httpBody = Data(
      """
      {
        "deviceId": "de71ce00-dead-beef-dead-beefdeadbeef",
        "displayName": "Blob",
        "gameCenterLocalPlayerId": "Unavailable Player Identification"
      }
      """.utf8)

    var environment = ServerEnvironment.unimplemented
    environment.database.fetchAppleReceipt = { _ in pure(.mock) }
    environment.database.insertPlayer = { request in
      pure(
        Player(
          accessToken: .init(rawValue: UUID(uuidString: "acce5500-dead-beef-dead-beefdeadbeef")!),
          createdAt: Date(timeIntervalSince1970: 1_234_567_890),
          deviceId: request.deviceId,
          displayName: request.displayName,
          gameCenterLocalPlayerId: request.gameCenterLocalPlayerId,
          id: .init(rawValue: UUID(uuidString: "deadbeef-dead-beef-dead-beefdeadbeef")!),
          sendDailyChallengeReminder: true,
          sendDailyChallengeSummary: true,
          timeZone: "America/New_York"
        )
      )
    }
    environment.database.fetchPlayerByDeviceId = { _ in pure(nil) }
    environment.database.fetchPlayerByGameCenterLocalPlayerId = { _ in pure(nil) }

    let middleware = siteMiddleware(environment: environment)
    let result = middleware(connection(from: request)).perform()

    _assertInlineSnapshot(matching: result, as: .conn, with: #"""
      POST /api/authenticate
      
      {
        "deviceId": "de71ce00-dead-beef-dead-beefdeadbeef",
        "displayName": "Blob",
        "gameCenterLocalPlayerId": "Unavailable Player Identification"
      }
      
      200 OK
      Content-Length: 1055
      Content-Type: application/json
      Referrer-Policy: strict-origin-when-cross-origin
      X-Content-Type-Options: nosniff
      X-Download-Options: noopen
      X-Frame-Options: SAMEORIGIN
      X-Permitted-Cross-Domain-Policies: none
      X-XSS-Protection: 1; mode=block
      
      {
        "appleReceipt" : {
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
        },
        "player" : {
          "accessToken" : "ACCE5500-DEAD-BEEF-DEAD-BEEFDEADBEEF",
          "createdAt" : 256260690,
          "deviceId" : "DE71CE00-DEAD-BEEF-DEAD-BEEFDEADBEEF",
          "displayName" : "Blob",
          "id" : "DEADBEEF-DEAD-BEEF-DEAD-BEEFDEADBEEF",
          "sendDailyChallengeReminder" : true,
          "sendDailyChallengeSummary" : true,
          "timeZone" : "America\/New_York"
        }
      }
      """#
    )
  }
}
