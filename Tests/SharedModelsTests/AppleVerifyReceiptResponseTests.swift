import CustomDump
import Foundation
import XCTest

@testable import SharedModels

class AppleVerifyReceiptResponseTests: XCTestCase {
  func testReceiptDecoding() throws {
    let json = """
      {
          "receipt": {
            "receipt_type": "ProductionSandbox",
            "adam_id": 0,
            "app_item_id": 0,
            "bundle_id": "co.pointfree.IsoWordsTesting",
            "application_version": "1",
            "download_id": 0,
            "version_external_identifier": 0,
            "receipt_creation_date": "2020-09-04 02:03:22 Etc/GMT",
            "receipt_creation_date_ms": "1599185002000",
            "receipt_creation_date_pst": "2020-09-03 19:03:22 America/Los_Angeles",
            "request_date": "2020-09-04 02:04:17 Etc/GMT",
            "request_date_ms": "1599185057917",
            "request_date_pst": "2020-09-03 19:04:17 America/Los_Angeles",
            "original_purchase_date": "2013-08-01 07:00:00 Etc/GMT",
            "original_purchase_date_ms": "1375340400000",
            "original_purchase_date_pst": "2013-08-01 00:00:00 America/Los_Angeles",
            "original_application_version": "1.0",
            "in_app": [
              {
                  "quantity": "1",
                  "product_id": "co.pointfree.isowords_testing.es",
                  "transaction_id": "1000000715012272",
                  "original_transaction_id": "1000000715012272",
                  "purchase_date": "2020-09-04 13:00:39 Etc/GMT",
                  "purchase_date_ms": "1599224439000",
                  "purchase_date_pst": "2020-09-04 06:00:39 America/Los_Angeles",
                  "original_purchase_date": "2020-09-04 13:00:39 Etc/GMT",
                  "original_purchase_date_ms": "1599224439000",
                  "original_purchase_date_pst": "2020-09-04 06:00:39 America/Los_Angeles",
                  "is_trial_period": "false"
              },
              {
                  "quantity": "1",
                  "product_id": "co.pointfree.isowords_testing.full_game",
                  "transaction_id": "1000000714700290",
                  "original_transaction_id": "1000000714700290",
                  "purchase_date": "2020-09-04 02:03:22 Etc/GMT",
                  "purchase_date_ms": "1599185002000",
                  "purchase_date_pst": "2020-09-03 19:03:22 America/Los_Angeles",
                  "original_purchase_date": "2020-09-04 02:03:22 Etc/GMT",
                  "original_purchase_date_ms": "1599185002000",
                  "original_purchase_date_pst": "2020-09-03 19:03:22 America/Los_Angeles",
                  "is_trial_period": "false"
              }
            ]
          },
          "environment": "Sandbox",
          "status": 0
      }
      """

    let response = try JSONDecoder().decode(AppleVerifyReceiptResponse.self, from: Data(json.utf8))
    expectNoDifference(
      response,
      AppleVerifyReceiptResponse(
        environment: .sandbox,
        isRetryable: false,
        receipt: .init(
          appItemId: 0,
          applicationVersion: "1",
          bundleId: "co.pointfree.IsoWordsTesting",
          inApp: [
            .init(
              originalPurchaseDate: .init(timeIntervalSince1970: 1_599_224_439),
              originalTransactionId: "1000000715012272",
              productId: "co.pointfree.isowords_testing.es",
              purchaseDate: .init(timeIntervalSince1970: 1_599_224_439),
              quantity: 1,
              transactionId: "1000000715012272"
            ),
            .init(
              originalPurchaseDate: .init(timeIntervalSince1970: 1_599_185_002),
              originalTransactionId: "1000000714700290",
              productId: "co.pointfree.isowords_testing.full_game",
              purchaseDate: .init(timeIntervalSince1970: 1_599_185_002),
              quantity: 1,
              transactionId: "1000000714700290"
            ),
          ],
          originalPurchaseDate: .init(timeIntervalSince1970: 1_375_340_400),
          receiptCreationDate: .init(timeIntervalSince1970: 1_599_185_002),
          requestDate: .init(timeIntervalSince1970: 1599185057.917)
        ),
        status: 0
      )
    )

    let encodedJsonData = try JSONEncoder().encode(response)
    let roundtripResponse = try JSONDecoder().decode(
      AppleVerifyReceiptResponse.self, from: encodedJsonData)

    expectNoDifference(roundtripResponse, response)
  }
}
