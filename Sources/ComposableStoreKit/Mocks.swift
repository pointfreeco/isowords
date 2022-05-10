import ComposableArchitecture

extension StoreKitClient {
  public static let noop = Self(
    addPayment: { _ in .none },
    appStoreReceiptURL: { nil },
    isAuthorizedForPayments: { false },
    fetchProducts: { _ in .none },
    finishTransaction: { _ in .none },
    observer: .none,
    requestReview: { .none },
    restoreCompletedTransactions: { .none }
  )
}

#if DEBUG
  import XCTestDynamicOverlay

  extension StoreKitClient {
    public static let failing = Self(
      addPayment: { _ in .failing("\(Self.self).addPayment is unimplemented") },
      appStoreReceiptURL: {
        XCTFail("\(Self.self).appStoreReceiptURL is unimplemented")
        return nil
      },
      isAuthorizedForPayments: {
        XCTFail("\(Self.self).isAuthorizedForPayments is unimplemented")
        return false
      },
      fetchProducts: { _ in .failing("\(Self.self).fetchProducts is unimplemented") },
      finishTransaction: { _ in .failing("\(Self.self).finishTransaction is unimplemented") },
      observer: .failing("\(Self.self).observer is unimplemented"),
      requestReview: { .failing("\(Self.self).requestReview is unimplemented") },
      restoreCompletedTransactions: { .failing("\(Self.self).fireAndForget is unimplemented") }
    )
  }
#endif
