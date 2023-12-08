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
  public static let testValue = Self()
}

extension StoreKitClient {
  public static let noop = Self(
    addPayment: { _ in },
    appStoreReceiptURL: { nil },
    isAuthorizedForPayments: { false },
    fetchProducts: { _ in try await Task.never() },
    finishTransaction: { _ in },
    observer: { .never },
    requestReview: {},
    restoreCompletedTransactions: {}
  )
}
