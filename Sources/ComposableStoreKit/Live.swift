import Combine
import ComposableArchitecture
import StoreKit

@available(iOSApplicationExtension, unavailable)
extension StoreKitClient {
  public static func live() -> Self {
    return Self(
      addPayment: { payment in
        .fireAndForget {
          SKPaymentQueue.default().add(payment)
        }
      },
      appStoreReceiptURL: { Bundle.main.appStoreReceiptURL },
      isAuthorizedForPayments: SKPaymentQueue.canMakePayments,
      fetchProducts: { products in
        .run { subscriber in
          let request = SKProductsRequest(productIdentifiers: products)
          var delegate: ProductRequest? = ProductRequest(subscriber: subscriber)
          request.delegate = delegate
          request.start()

          return AnyCancellable {
            request.cancel()
            request.delegate = nil
            delegate = nil
          }
        }
      },
      finishTransaction: { transaction in
        .fireAndForget {
          guard let skTransaction = transaction.rawValue else {
            assertionFailure("The rawValue of this transaction should not be nil: \(transaction)")
            return
          }
          SKPaymentQueue.default().finishTransaction(skTransaction)
        }
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
        .fireAndForget {
          #if canImport(UIKit)
            guard let windowScene = UIApplication.shared.windows.first?.windowScene
            else { return }

            SKStoreReviewController.requestReview(in: windowScene)
          #endif
        }
      },
      restoreCompletedTransactions: {
        .fireAndForget {
          SKPaymentQueue.default().restoreCompletedTransactions()
        }
      }
    )
  }
}

private class ProductRequest: NSObject, SKProductsRequestDelegate {
  let subscriber: Effect<StoreKitClient.ProductsResponse, Error>.Subscriber

  init(subscriber: Effect<StoreKitClient.ProductsResponse, Error>.Subscriber) {
    self.subscriber = subscriber
  }

  func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
    self.subscriber.send(
      .init(
        invalidProductIdentifiers: response.invalidProductIdentifiers,
        products: response.products.map(StoreKitClient.Product.init(rawValue:))
      )
    )
    self.subscriber.send(completion: .finished)
  }

  func request(_ request: SKRequest, didFailWithError error: Error) {
    self.subscriber.send(completion: .failure(error))
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
