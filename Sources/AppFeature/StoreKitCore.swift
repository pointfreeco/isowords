import Combine
import ComposableArchitecture
import ComposableStoreKit
import GameKit
import Overture
import ServerRouter
import SharedModels

public struct ReceiptFinalizationEnvelope: Equatable {
  let transactions: [StoreKitClient.PaymentTransaction]
  let verifyEnvelope: VerifyReceiptEnvelope
}

extension Reducer where Action == AppAction, Environment == AppEnvironment {
  func storeKit() -> Self {
    self.combined(
      with: Reducer { _, action, environment in
        switch action {
        case .appDelegate(.didFinishLaunching):
          return .run { send in
            for await event in environment.storeKit.observerAsync() {
              await send(.paymentTransaction(event))
            }
          }

        case let .paymentTransaction(.updatedTransactions(transactions)):
          return .run { send in
            let verifiableTransactions = transactions.filter { $0.transactionState.canBeVerified }
            let otherTransactions = transactions.filter { !$0.transactionState.canBeVerified }

            if
              !verifiableTransactions.isEmpty,
              let appStoreReceiptURL = environment.storeKit.appStoreReceiptURL(),
              let receiptData = try? Data(contentsOf: appStoreReceiptURL, options: .alwaysMapped)
            {
              await send(
                .verifyReceiptResponse(
                  TaskResult {
                    try await ReceiptFinalizationEnvelope(
                      transactions: transactions,
                      verifyEnvelope: environment.apiClient.apiRequestAsync(
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
                await environment.storeKit.finishTransaction(transaction)

              case .deferred, .purchased, .purchasing, .restored:
                return

              @unknown default:
                return
              }
            }
          }

        case let .verifyReceiptResponse(.success(envelope)):
          return .fireAndForget {
            for transaction in envelope.transactions
            where envelope.verifyEnvelope.verifiedProductIds
              .contains(where: { $0 == transaction.payment.productIdentifier }) {
                await environment.storeKit.finishTransaction(transaction)
            }
          }

        case .verifyReceiptResponse(.failure):
          return .none

        default:
          return .none
        }
      }
    )
  }
}
