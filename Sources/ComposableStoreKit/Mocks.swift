import ComposableArchitecture

extension StoreKitClient {
  public static let noop = Self(
    addPayment: { _ in },
    appStoreReceiptURL: { nil },
    isAuthorizedForPayments: { false },
    fetchProducts: { _ in try await Task.never() },
    finishTransaction: { _ in },
    observer: { AsyncStream { _ in } },
    requestReview: {},
    restoreCompletedTransactions: {}
  )
}

#if DEBUG
  import XCTestDynamicOverlay

  extension StoreKitClient {
    public static let failing = Self(
      addPayment: XCTUnimplemented("\(Self.self).addPayment"),
      appStoreReceiptURL: XCTUnimplemented("\(Self.self).appStoreReceiptURL", placeholder: nil),
      isAuthorizedForPayments: XCTUnimplemented(
        "\(Self.self).isAuthorizedForPayments", placeholder: false
      ),
      fetchProducts: XCTUnimplemented("\(Self.self).fetchProducts"),
      finishTransaction: XCTUnimplemented("\(Self.self).finishTransaction"),
      observer: XCTUnimplemented("\(Self.self).observer", placeholder: .finished),
      requestReview: XCTUnimplemented("\(Self.self).requestReview"),
      restoreCompletedTransactions: XCTUnimplemented(
        "\(Self.self).restoreCompletedTransactions"
      )
    )
  }
#endif
