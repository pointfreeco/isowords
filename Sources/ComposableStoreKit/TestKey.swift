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
    addPayment: unimplemented("\(Self.self).addPayment"),
    appStoreReceiptURL: unimplemented("\(Self.self).appStoreReceiptURL", placeholder: nil),
    isAuthorizedForPayments: unimplemented(
      "\(Self.self).isAuthorizedForPayments", placeholder: false
    ),
    fetchProducts: unimplemented("\(Self.self).fetchProducts"),
    finishTransaction: unimplemented("\(Self.self).finishTransaction"),
    observer: unimplemented("\(Self.self).observer", placeholder: .finished),
    requestReview: unimplemented("\(Self.self).requestReview"),
    restoreCompletedTransactions: unimplemented(
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
