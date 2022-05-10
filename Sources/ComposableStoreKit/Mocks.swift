import ComposableArchitecture

extension StoreKitClient {
  public static let noop = Self(
    addPayment: { _ in },
    appStoreReceiptURL: { nil },
    isAuthorizedForPayments: { false },
    fetchProducts: { _ in .init(invalidProductIdentifiers: [], products: []) },
    finishTransaction: { _ in },
    observer: .none,
    requestReview: { },
    restoreCompletedTransactions: { }
  )
}

#if DEBUG
  import XCTestDynamicOverlay

  extension StoreKitClient {
    public static let failing = Self(
      addPayment: { _ in XCTFail("\(Self.self).addPayment is unimplemented") },
      appStoreReceiptURL: {
        XCTFail("\(Self.self).appStoreReceiptURL is unimplemented")
        return nil
      },
      isAuthorizedForPayments: {
        XCTFail("\(Self.self).isAuthorizedForPayments is unimplemented")
        return false
      },
      fetchProducts: { _ in
        XCTFail("\(Self.self).fetchProducts is unimplemented")
        struct Unimplemented: Error {}
        throw Unimplemented()
      },
      finishTransaction: { _ in XCTFail("\(Self.self).finishTransaction is unimplemented") },
      observer: .failing("\(Self.self).observer is unimplemented"),
      requestReview: { XCTFail("\(Self.self).requestReview is unimplemented") },
      restoreCompletedTransactions: { XCTFail("\(Self.self).fireAndForget is unimplemented") }
    )
  }
#endif
