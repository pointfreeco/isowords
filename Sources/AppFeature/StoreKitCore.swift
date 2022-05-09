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
          return environment.storeKit.observer
            .map(AppAction.paymentTransaction)

        case let .paymentTransaction(.updatedTransactions(transactions)):
          let verifiableTransactions = transactions.filter { $0.transactionState.canBeVerified }
          let otherTransactions = transactions.filter { !$0.transactionState.canBeVerified }

          let verifyReceiptEffect: Effect<AppAction, Never>
          if verifiableTransactions.isEmpty {
            verifyReceiptEffect = .none
          } else if let appStoreReceiptURL = environment.storeKit.appStoreReceiptURL(),
            let receiptData = try? Data(contentsOf: appStoreReceiptURL, options: .alwaysMapped)
          {
            verifyReceiptEffect = .task { @MainActor in
              await .verifyReceiptResponse(
                TaskResult {
                  ReceiptFinalizationEnvelope(
                    transactions: transactions,
                    verifyEnvelope: try await environment.apiClient.apiRequest(
                      route: .verifyReceipt(receiptData),
                      as: VerifyReceiptEnvelope.self
                    )
                  )
                }
              )
            }
          } else {
            // TODO: what to do if there is no receipt data?
            verifyReceiptEffect = .none
          }

          let otherTransactionEffects: [Effect<Action, Never>] = otherTransactions.map {
            transaction in
            switch transaction.transactionState {
            case .purchasing:
              // TODO: what to do? nothing?
              return .none

            case .purchased, .restored:
              return .none

            case .failed:
              return environment.storeKit.finishTransaction(transaction)
                .fireAndForget()

            case .deferred:
              // TODO: Update UI to show await parent approval
              return .none

            @unknown default:
              return .none
            }
          }

          return .merge([verifyReceiptEffect] + otherTransactionEffects)

        case let .verifyReceiptResponse(.success(envelope)):
          return .merge(
            envelope.transactions
              .compactMap { transaction in
                envelope.verifyEnvelope.verifiedProductIds
                  .contains { $0 == transaction.payment.productIdentifier }
                  ? environment.storeKit.finishTransaction(transaction).fireAndForget()
                  : nil
              }
          )

        case .verifyReceiptResponse(.failure):
          return .none

        default:
          return .none
        }
      })
  }
}
