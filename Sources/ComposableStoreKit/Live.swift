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
      addPaymentAsync: { SKPaymentQueue.default().add($0) },
      appStoreReceiptURL: { Bundle.main.appStoreReceiptURL },
      isAuthorizedForPayments: { SKPaymentQueue.canMakePayments() },
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
      fetchProductsAsync: { products in
        let stream = AsyncThrowingStream<ProductsResponse, Error> { continuation in
          let request = SKProductsRequest(productIdentifiers: products)
          let delegate = ProductRequestAsync(continuation: continuation)
          request.delegate = delegate
          request.start()
          continuation.onTermination = { _ in
            request.cancel()
            _ = delegate
          }
        }
        guard let response = try await stream.first(where: { _ in true })
        else { throw CancellationError() }
        return response
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
      observerAsync: {
        AsyncStream { continuation in
          let observer = ObserverAsync(continuation: continuation)
          SKPaymentQueue.default().add(observer)
          continuation.onTermination = { _ in SKPaymentQueue.default().remove(observer) }
        }
      },
      requestReview: {
        guard let windowScene = await UIApplication.shared.windows.first?.windowScene
        else { return }
        await SKStoreReviewController.requestReview(in: windowScene)
      },
      restoreCompletedTransactions: {
        .fireAndForget {
          SKPaymentQueue.default().restoreCompletedTransactions()
        }
      },
      restoreCompletedTransactionsAsync: { SKPaymentQueue.default().restoreCompletedTransactions() }
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

private class ProductRequestAsync: NSObject, SKProductsRequestDelegate {
  let continuation: AsyncThrowingStream<StoreKitClient.ProductsResponse, Error>.Continuation

  init(continuation: AsyncThrowingStream<StoreKitClient.ProductsResponse, Error>.Continuation) {
    self.continuation = continuation
  }

  func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
    self.continuation.yield(
      .init(
        invalidProductIdentifiers: response.invalidProductIdentifiers,
        products: response.products.map(StoreKitClient.Product.init(rawValue:))
      )
    )
    self.continuation.finish()
  }

  func request(_ request: SKRequest, didFailWithError error: Error) {
    self.continuation.finish(throwing: error)
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

private class ObserverAsync: NSObject, SKPaymentTransactionObserver {
  let continuation: AsyncStream<StoreKitClient.PaymentTransactionObserverEvent>.Continuation

  init(continuation: AsyncStream<StoreKitClient.PaymentTransactionObserverEvent>.Continuation) {
    self.continuation = continuation
  }

  func paymentQueue(
    _ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]
  ) {
    self.continuation.yield(
      .updatedTransactions(
        transactions.map(StoreKitClient.PaymentTransaction.init(rawValue:))
      )
    )
  }

  func paymentQueue(
    _ queue: SKPaymentQueue, removedTransactions transactions: [SKPaymentTransaction]
  ) {
    self.continuation.yield(
      .removedTransactions(
        transactions.map(StoreKitClient.PaymentTransaction.init(rawValue:))
      )
    )
  }

  func paymentQueueRestoreCompletedTransactionsFinished(_ queue: SKPaymentQueue) {
    self.continuation.yield(
      .restoreCompletedTransactionsFinished(
        transactions: queue.transactions.map(StoreKitClient.PaymentTransaction.init)
      )
    )
  }

  func paymentQueue(
    _ queue: SKPaymentQueue, restoreCompletedTransactionsFailedWithError error: Error
  ) {
    // TODO: Should this use TaskResult<Never> instead? TaskFailure?
    self.continuation.yield(.restoreCompletedTransactionsFailed(error as NSError))
  }
}
