import Combine
import ComposableArchitecture
import ComposableStoreKit
import SharedModels
import XCTest

@testable import ServerConfig
@testable import SettingsFeature

fileprivate extension DependencyValues {
  mutating func setUpDefaults() {
    self.apiClient.baseUrl = { URL(string: "http://localhost:9876")! }
    self.applicationClient.alternateIconName = { nil }
    self.build.number = { 42 }
    self.mainQueue = .immediate
    self.userNotifications.getNotificationSettings = {
      (try? await Task.never()) ?? .init(authorizationStatus: .notDetermined)
    }
  }
}

class SettingsPurchaseTests: XCTestCase {
  @MainActor
  func testUpgrade_HappyPath() async throws {
    let didAddPaymentProductIdentifier = ActorIsolated<String?>(nil)
    let storeKitObserver = AsyncStream<StoreKitClient.PaymentTransactionObserverEvent>
      .makeStream()

    let store = TestStore(
      initialState: Settings.State()
    ) {
      Settings()
    } withDependencies: {
      $0.setUpDefaults()
      $0.serverConfig.config = {
        .init(productIdentifiers: .init(fullGame: "xyz.isowords.full_game"))
      }
      $0.apiClient.currentPlayer = { .some(.blobWithoutPurchase) }
      $0.apiClient.refreshCurrentPlayer = { .blobWithPurchase }
      $0.storeKit.addPayment = {
        let productIdentifier = $0.productIdentifier
        await didAddPaymentProductIdentifier.setValue(productIdentifier)
      }
      $0.storeKit.fetchProducts = { _ in
          .init(invalidProductIdentifiers: [], products: [.fullGame])
      }
      $0.storeKit.observer = { storeKitObserver.stream }
    }

    let task = await store.send(.task) {
      $0.buildNumber = 42
      $0.developer.currentBaseUrl = .localhost
    }
    await store.receive(\.productsResponse.success) {
      $0.fullGameProduct = .success(.fullGame)
    }
    await store.send(.tappedProduct(.fullGame)) {
      $0.isPurchasing = true
    }
    await didAddPaymentProductIdentifier.withValue {
      XCTAssertNoDifference($0, "xyz.isowords.full_game")
    }
    storeKitObserver.continuation.yield(.updatedTransactions([.purchasing]))
    storeKitObserver.continuation.yield(.updatedTransactions([.purchased]))
    storeKitObserver.continuation.yield(.removedTransactions([.purchased]))

    await store.receive(\.paymentTransaction.updatedTransactions)
    await store.receive(\.paymentTransaction.updatedTransactions)
    await store.receive(\.paymentTransaction.removedTransactions) {
      $0.isPurchasing = false
    }
    await store.receive(\.currentPlayerRefreshed.success) {
      $0.fullGamePurchasedAt = .mock
    }
    await task.cancel()
  }

  @MainActor
  func testRestore_HappyPath() async throws {
    let didRestoreCompletedTransactions = ActorIsolated(false)
    let storeKitObserver = AsyncStream<StoreKitClient.PaymentTransactionObserverEvent>
      .makeStream()
    let store = TestStore(
      initialState: Settings.State()
    ) {
      Settings()
    } withDependencies: {
      $0.setUpDefaults()
      $0.serverConfig.config = {
        .init(productIdentifiers: .init(fullGame: "xyz.isowords.full_game"))
      }
      $0.apiClient.currentPlayer = { .some(.blobWithoutPurchase) }
      $0.apiClient.refreshCurrentPlayer = { .blobWithPurchase }
      $0.storeKit.restoreCompletedTransactions = {
        await didRestoreCompletedTransactions.setValue(true)
      }
      $0.storeKit.fetchProducts = { _ in
          .init(invalidProductIdentifiers: [], products: [.fullGame])
      }
      $0.storeKit.observer = { storeKitObserver.stream }
    }

    let task = await store.send(.task) {
      $0.buildNumber = 42
      $0.developer.currentBaseUrl = .localhost
    }
    await store.receive(\.productsResponse.success) {
      $0.fullGameProduct = .success(.fullGame)
    }
    await store.send(.restoreButtonTapped) {
      $0.isRestoring = true
    }

    await didRestoreCompletedTransactions.withValue { XCTAssertNoDifference($0, true) }
    storeKitObserver.continuation.yield(.updatedTransactions([.restored]))
    storeKitObserver.continuation.yield(.removedTransactions([.restored]))
    storeKitObserver.continuation.yield(
      .restoreCompletedTransactionsFinished(transactions: [.restored]))

    await store.receive(\.paymentTransaction.updatedTransactions)
    await store.receive(\.paymentTransaction.removedTransactions)
    await store.receive(\.paymentTransaction.restoreCompletedTransactionsFinished) {
      $0.isRestoring = false
    }
    await store.receive(\.currentPlayerRefreshed.success) {
      $0.fullGamePurchasedAt = .mock
    }
    await task.cancel()
  }

  @MainActor
  func testRestore_NoPurchasesPath() async throws {
    let didRestoreCompletedTransactions = ActorIsolated(false)
    let storeKitObserver = AsyncStream<StoreKitClient.PaymentTransactionObserverEvent>
      .makeStream()
    let store = TestStore(
      initialState: Settings.State()
    ) {
      Settings()
    } withDependencies: {
      $0.setUpDefaults()
      $0.serverConfig.config = {
        .init(productIdentifiers: .init(fullGame: "xyz.isowords.full_game"))
      }
      $0.apiClient.currentPlayer = { .some(.blobWithoutPurchase) }
      $0.storeKit.restoreCompletedTransactions = {
        await didRestoreCompletedTransactions.setValue(true)
      }
      $0.storeKit.fetchProducts = { _ in
          .init(invalidProductIdentifiers: [], products: [.fullGame])
      }
      $0.storeKit.observer = { storeKitObserver.stream }
    }

    let task = await store.send(.task) {
      $0.buildNumber = 42
      $0.developer.currentBaseUrl = .localhost
    }
    await store.receive(\.productsResponse.success) {
      $0.fullGameProduct = .success(.fullGame)
    }
    await store.send(.restoreButtonTapped) {
      $0.isRestoring = true
    }

    await didRestoreCompletedTransactions.withValue { XCTAssertNoDifference($0, true) }
    storeKitObserver.continuation.yield(.restoreCompletedTransactionsFinished(transactions: []))

    await store.receive(\.paymentTransaction.restoreCompletedTransactionsFinished) {
      $0.isRestoring = false
      $0.alert = .noRestoredPurchases
    }

    await task.cancel()
  }

  @MainActor
  func testRestore_ErrorPath() async throws {
    let didRestoreCompletedTransactions = ActorIsolated(false)
    let storeKitObserver = AsyncStream<StoreKitClient.PaymentTransactionObserverEvent>
      .makeStream()
    let store = TestStore(
      initialState: Settings.State()
    ) {
      Settings()
    } withDependencies: {
      $0.setUpDefaults()
      $0.serverConfig.config = {
        .init(productIdentifiers: .init(fullGame: "xyz.isowords.full_game"))
      }
      $0.apiClient.currentPlayer = { .some(.blobWithoutPurchase) }
      $0.storeKit.restoreCompletedTransactions = {
        await didRestoreCompletedTransactions.setValue(true)
      }
      $0.storeKit.fetchProducts = { _ in
          .init(invalidProductIdentifiers: [], products: [.fullGame])
      }
      $0.storeKit.observer = { storeKitObserver.stream }
    }

    let task = await store.send(.task) {
      $0.buildNumber = 42
      $0.developer.currentBaseUrl = .localhost
    }
    await store.receive(\.productsResponse.success) {
      $0.fullGameProduct = .success(.fullGame)
    }
    await store.send(.restoreButtonTapped) {
      $0.isRestoring = true
    }

    await didRestoreCompletedTransactions.withValue { XCTAssert($0) }

    let restoreCompletedTransactionsError = NSError(domain: "", code: 1)
    storeKitObserver.continuation
      .yield(.restoreCompletedTransactionsFailed(restoreCompletedTransactionsError))

    await store.receive(\.paymentTransaction.restoreCompletedTransactionsFailed) {
      $0.isRestoring = false
      $0.alert = .restoredPurchasesFailed
    }

    await task.cancel()
  }
}

extension CurrentPlayerEnvelope {
  static let blobWithPurchase = Self(appleReceipt: .mock, player: .blob)
  static let blobWithoutPurchase = Self(appleReceipt: nil, player: .blob)
}

extension StoreKitClient.Payment {
  static let fullGame = Self(
    applicationUsername: nil,
    productIdentifier: "xyz.isowords.full_game",
    quantity: 1,
    requestData: nil,
    simulatesAskToBuyInSandbox: false
  )
}

extension StoreKitClient.PaymentTransaction {
  static let purchasing = Self(
    error: nil,
    original: nil,
    payment: .fullGame,
    rawValue: nil,
    transactionDate: .mock,
    transactionIdentifier: "deadbeef",
    transactionState: .purchasing
  )
  static let purchased = Self(
    error: nil,
    original: nil,
    payment: .fullGame,
    rawValue: nil,
    transactionDate: .mock,
    transactionIdentifier: "deadbeef",
    transactionState: .purchased
  )
  static let restored = Self(
    error: nil,
    original: nil,
    payment: .fullGame,
    rawValue: nil,
    transactionDate: .mock,
    transactionIdentifier: "deadbeef",
    transactionState: .restored
  )
}

extension StoreKitClient.Product {
  static let fullGame = Self(
    downloadContentLengths: [],
    downloadContentVersion: "",
    isDownloadable: false,
    localizedDescription: "Full game",
    localizedTitle: "Full game",
    price: 5,
    priceLocale: .init(identifier: "en_US"),
    productIdentifier: "xyz.isowords.full_game"
  )
}
