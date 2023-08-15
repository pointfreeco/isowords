import ComposableArchitecture
import ComposableStoreKit
import Foundation
import SharedModels

public struct ReceiptFinalizationEnvelope: Equatable {
  let transactions: [StoreKitClient.PaymentTransaction]
  let verifyEnvelope: VerifyReceiptEnvelope
}

public struct StoreKitLogic<State>: Reducer {
  @Dependency(\.apiClient) var apiClient
  @Dependency(\.storeKit) var storeKit

  public func reduce(
    into _: inout State, action: AppReducer.Action
  ) -> Effect<AppReducer.Action> {
    switch action {
    case .appDelegate(.didFinishLaunching):
      return .run { send in
        for await event in self.storeKit.observer() {
          await send(.paymentTransaction(event))
        }
      }

    case let .paymentTransaction(.updatedTransactions(transactions)):
      return .run { send in
        let verifiableTransactions = transactions.filter { $0.transactionState.canBeVerified }
        let otherTransactions = transactions.filter { !$0.transactionState.canBeVerified }

        if !verifiableTransactions.isEmpty,
          let appStoreReceiptURL = self.storeKit.appStoreReceiptURL(),
          let receiptData = try? Data(contentsOf: appStoreReceiptURL, options: .alwaysMapped)
        {
          await send(
            .verifyReceiptResponse(
              TaskResult {
                try await ReceiptFinalizationEnvelope(
                  transactions: transactions,
                  verifyEnvelope: self.apiClient.apiRequest(
                    route: .verifyReceipt(receiptData),
                    as: VerifyReceiptEnvelope.self
                  )
                )
              }
            )
          )
        }

        for transaction in otherTransactions {
          switch transaction.transactionState {
          case .failed:
            await self.storeKit.finishTransaction(transaction)

          case .deferred, .purchased, .purchasing, .restored:
            return

          @unknown default:
            return
          }
        }
      }

    case let .verifyReceiptResponse(.success(envelope)):
      return .run { _ in
        for transaction in envelope.transactions
        where envelope.verifyEnvelope.verifiedProductIds
          .contains(where: { $0 == transaction.payment.productIdentifier })
        {
          await self.storeKit.finishTransaction(transaction)
        }
      }

    case .verifyReceiptResponse(.failure):
      return .none

    default:
      return .none
    }
  }
}
