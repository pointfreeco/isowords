import ComposableArchitecture
import ComposableStoreKit
import Dependencies
import Foundation
import SharedModels

extension AppReducer {
  func observePaymentTransactions() async {
    for await event in storeKit.observer() {
      guard case let .updatedTransactions(transactions) = event
      else { continue }
      await finalize(transactions: transactions)
    }
  }

  private func finalize(transactions: [StoreKitClient.PaymentTransaction]) async {
    let verifiableTransactions = transactions.filter { $0.transactionState.canBeVerified }
    let otherTransactions = transactions.filter { !$0.transactionState.canBeVerified }

    if !verifiableTransactions.isEmpty,
      let appStoreReceiptURL = storeKit.appStoreReceiptURL(),
      let receiptData = try? Data(contentsOf: appStoreReceiptURL, options: .alwaysMapped),
      let verifyEnvelope = try? await apiClient.apiRequest(
        route: .verifyReceipt(receiptData),
        as: VerifyReceiptEnvelope.self
      )
    {
      for transaction in transactions
      where verifyEnvelope.verifiedProductIds
        .contains(where: { $0 == transaction.payment.productIdentifier })
      {
        await storeKit.finishTransaction(transaction)
      }
    }

    for transaction in otherTransactions {
      switch transaction.transactionState {
      case .failed:
        await storeKit.finishTransaction(transaction)

      case .deferred, .purchased, .purchasing, .restored:
        return

      @unknown default:
        return
      }
    }
  }
}
