import Foundation

@testable import SharedModels

extension AppleVerifyReceiptResponse {
  static let fullGame = Self(
    environment: .production,
    isRetryable: false,
    receipt: .init(
      appItemId: 1,
      applicationVersion: "1",
      bundleId: "co.pointfree.tests",
      inApp: [
        .init(
          originalPurchaseDate: Date(),
          originalTransactionId: "deadbeef",
          productId: "co.pointfree.full_game",
          purchaseDate: Date(),
          quantity: 1,
          transactionId: "deadbeef"
        )
      ],
      originalPurchaseDate: Date(),
      receiptCreationDate: Date(),
      requestDate: Date()
    ),
    status: 0
  )
}
