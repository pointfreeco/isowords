import Combine
import ComposableArchitecture
import StoreKit

@available(iOSApplicationExtension, unavailable)
extension StoreKitClient {
  public static func live() -> Self {
    return Self(
      addPayment: { payment in
        SKPaymentQueue.default().add(payment)
      },
      appStoreReceiptURL: { Bundle.main.appStoreReceiptURL },
      isAuthorizedForPayments: SKPaymentQueue.canMakePayments,
      fetchProducts: { products in
        try await withUnsafeThrowingContinuation { continuation in
          let request = SKProductsRequest(productIdentifiers: products)
          let delegate = ProductRequest {
            continuation.resume(with: $0)
          }
          request.delegate = delegate
          request.start()
        }
      },
      finishTransaction: { transaction in
        guard let skTransaction = transaction.rawValue else {
          assertionFailure("The rawValue of this transaction should not be nil: \(transaction)")
          return
        }
        SKPaymentQueue.default().finishTransaction(skTransaction)
      },
      observer: Effect.run { subscriber in
        let observer = Observer(subscriber: subscriber)
        SKPaymentQueue.default().add(observer)
        return AnyCancellable {
          SKPaymentQueue.default().remove(observer)
        }
      }
      .share()
      .eraseToEffect(),
      requestReview: {
        #if canImport(UIKit)
          guard let windowScene = await UIApplication.shared.windows.first?.windowScene
          else { return }

          SKStoreReviewController.requestReview(in: windowScene)
        #endif
      },
      restoreCompletedTransactions: {
        SKPaymentQueue.default().restoreCompletedTransactions()
      }
    )
  }
}

private class ProductRequest: NSObject, SKProductsRequestDelegate {
  let completion: (Result<StoreKitClient.ProductsResponse, Error>) -> Void

  init(completion: @escaping (Result<StoreKitClient.ProductsResponse, Error>) -> Void) {
    self.completion = completion
  }

  func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
    self.completion(
        .success(
          .init(
            invalidProductIdentifiers: response.invalidProductIdentifiers,
            products: response.products.map(StoreKitClient.Product.init(rawValue:))
          )
        )
    )
  }

  func request(_ request: SKRequest, didFailWithError error: Error) {
    self.completion(.failure(error))
  }
}

private class Observer: NSObject, SKPaymentTransactionObserver {
  let subscriber: Effect<StoreKitClient.PaymentTransactionObserverEvent, Never>.Subscriber

  init(subscriber: Effect<StoreKitClient.PaymentTransactionObserverEvent, Never>.Subscriber) {
    self.subscriber = subscriber
  }

  func paymentQueue(
    _ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]
  ) {
    self.subscriber.send(
      .updatedTransactions(
        transactions.map(StoreKitClient.PaymentTransaction.init(rawValue:))
      )
    )
  }

  func paymentQueue(
    _ queue: SKPaymentQueue, removedTransactions transactions: [SKPaymentTransaction]
  ) {
    self.subscriber.send(
      .removedTransactions(
        transactions.map(StoreKitClient.PaymentTransaction.init(rawValue:))
      )
    )
  }

  func paymentQueueRestoreCompletedTransactionsFinished(_ queue: SKPaymentQueue) {
    self.subscriber.send(
      .restoreCompletedTransactionsFinished(
        transactions: queue.transactions.map(StoreKitClient.PaymentTransaction.init)
      )
    )
  }

  func paymentQueue(
    _ queue: SKPaymentQueue, restoreCompletedTransactionsFailedWithError error: Error
  ) {
    self.subscriber.send(.restoreCompletedTransactionsFailed(error as NSError))
  }
}
