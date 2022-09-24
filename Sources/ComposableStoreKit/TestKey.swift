import Dependencies
import XCTestDynamicOverlay

extension DependencyValues {
  public var storeKit: StoreKitClient {
    get { self[StoreKitClient.self] }
    set { self[StoreKitClient.self] = newValue }
  }
}

extension StoreKitClient: TestDependencyKey {
  public static let previewValue = Self.noop

  public static let testValue = Self(
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
