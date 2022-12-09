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
//    self.fileClient.save = { @Sendable _, _ in }
    self.persistenceClient.save = { @Sendable _, _ in }
    self.userNotifications.getNotificationSettings = {
      (try? await Task.never()) ?? .init(authorizationStatus: .notDetermined)
    }
  }
}

@MainActor
class SettingsPurchaseTests: XCTestCase {
  func testUpgrade_HappyPath() async throws {
    let store = TestStore(
      initialState: Settings.State(),
      reducer: Settings()
    )

    let didAddPaymentProductIdentifier = ActorIsolated<String?>(nil)
    let storeKitObserver = AsyncStream<StoreKitClient.PaymentTransactionObserverEvent>
      .streamWithContinuation()

    store.dependencies.setUpDefaults()
    store.dependencies.serverConfig.config = {
      .init(productIdentifiers: .init(fullGame: "xyz.isowords.full_game"))
    }
    store.dependencies.apiClient.currentPlayer = { .some(.blobWithoutPurchase) }
    store.dependencies.apiClient.refreshCurrentPlayer = { .blobWithPurchase }
    store.dependencies.storeKit.addPayment = {
      await didAddPaymentProductIdentifier.setValue($0.productIdentifier)
    }
    store.dependencies.storeKit.fetchProducts = { _ in
      .init(invalidProductIdentifiers: [], products: [.fullGame])
    }
    store.dependencies.storeKit.observer = { storeKitObserver.stream }

    let task = await store.send(.task) {
      $0.buildNumber = 42
      $0.developer.currentBaseUrl = .localhost
    }
    await store.receive(
      .productsResponse(.success(.init(invalidProductIdentifiers: [], products: [.fullGame])))
    ) {
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

    await store.receive(.paymentTransaction(.updatedTransactions([.purchasing])))
    await store.receive(.paymentTransaction(.updatedTransactions([.purchased])))
    await store.receive(.paymentTransaction(.removedTransactions([.purchased]))) {
      $0.isPurchasing = false
    }
    await store.receive(.currentPlayerRefreshed(.success(.blobWithPurchase))) {
      $0.fullGamePurchasedAt = .mock
    }
    await task.cancel()
  }

  func testRestore_HappyPath() async throws {
    let store = TestStore(
      initialState: Settings.State(),
      reducer: Settings()
    )

    let didRestoreCompletedTransactions = ActorIsolated(false)
    let storeKitObserver = AsyncStream<StoreKitClient.PaymentTransactionObserverEvent>
      .streamWithContinuation()

    store.dependencies.setUpDefaults()
    store.dependencies.serverConfig.config = {
      .init(productIdentifiers: .init(fullGame: "xyz.isowords.full_game"))
    }
    store.dependencies.apiClient.currentPlayer = { .some(.blobWithoutPurchase) }
    store.dependencies.apiClient.refreshCurrentPlayer = { .blobWithPurchase }
    store.dependencies.storeKit.restoreCompletedTransactions = {
      await didRestoreCompletedTransactions.setValue(true)
    }
    store.dependencies.storeKit.fetchProducts = { _ in
      .init(invalidProductIdentifiers: [], products: [.fullGame])
    }
    store.dependencies.storeKit.observer = { storeKitObserver.stream }

    let task = await store.send(.task) {
      $0.buildNumber = 42
      $0.developer.currentBaseUrl = .localhost
    }
    await store.receive(
      .productsResponse(.success(.init(invalidProductIdentifiers: [], products: [.fullGame])))
    ) {
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

    await store.receive(.paymentTransaction(.updatedTransactions([.restored])))
    await store.receive(.paymentTransaction(.removedTransactions([.restored])))
    await store.receive(
      .paymentTransaction(.restoreCompletedTransactionsFinished(transactions: [.restored]))
    ) {
      $0.isRestoring = false
    }
    await store.receive(.currentPlayerRefreshed(.success(.blobWithPurchase))) {
      $0.fullGamePurchasedAt = .mock
    }
    await task.cancel()
  }

  func testRestore_NoPurchasesPath() async throws {
    let store = TestStore(
      initialState: Settings.State(),
      reducer: Settings()
    )

    let didRestoreCompletedTransactions = ActorIsolated(false)
    let storeKitObserver = AsyncStream<StoreKitClient.PaymentTransactionObserverEvent>
      .streamWithContinuation()

    store.dependencies.setUpDefaults()
    store.dependencies.serverConfig.config = {
      .init(productIdentifiers: .init(fullGame: "xyz.isowords.full_game"))
    }
    store.dependencies.apiClient.currentPlayer = { .some(.blobWithoutPurchase) }
    store.dependencies.storeKit.restoreCompletedTransactions = {
      await didRestoreCompletedTransactions.setValue(true)
    }
    store.dependencies.storeKit.fetchProducts = { _ in
      .init(invalidProductIdentifiers: [], products: [.fullGame])
    }
    store.dependencies.storeKit.observer = { storeKitObserver.stream }

    let task = await store.send(.task) {
      $0.buildNumber = 42
      $0.developer.currentBaseUrl = .localhost
    }
    await store.receive(
      .productsResponse(.success(.init(invalidProductIdentifiers: [], products: [.fullGame])))
    ) {
      $0.fullGameProduct = .success(.fullGame)
    }
    await store.send(.restoreButtonTapped) {
      $0.isRestoring = true
    }

    await didRestoreCompletedTransactions.withValue { XCTAssertNoDifference($0, true) }
    storeKitObserver.continuation.yield(.restoreCompletedTransactionsFinished(transactions: []))

    await store.receive(
      .paymentTransaction(.restoreCompletedTransactionsFinished(transactions: []))
    ) {
      $0.isRestoring = false
      $0.alert = .noRestoredPurchases
    }

    await task.cancel()
  }

  func testRestore_ErrorPath() async throws {
    let store = TestStore(
      initialState: Settings.State(),
      reducer: Settings()
    )

    let didRestoreCompletedTransactions = ActorIsolated(false)
    let storeKitObserver = AsyncStream<StoreKitClient.PaymentTransactionObserverEvent>
      .streamWithContinuation()

    store.dependencies.setUpDefaults()
    store.dependencies.serverConfig.config = {
      .init(productIdentifiers: .init(fullGame: "xyz.isowords.full_game"))
    }
    store.dependencies.apiClient.currentPlayer = { .some(.blobWithoutPurchase) }
    store.dependencies.storeKit.restoreCompletedTransactions = {
      await didRestoreCompletedTransactions.setValue(true)
    }
    store.dependencies.storeKit.fetchProducts = { _ in
      .init(invalidProductIdentifiers: [], products: [.fullGame])
    }
    store.dependencies.storeKit.observer = { storeKitObserver.stream }

    let task = await store.send(.task) {
      $0.buildNumber = 42
      $0.developer.currentBaseUrl = .localhost
    }
    await store.receive(
      .productsResponse(.success(.init(invalidProductIdentifiers: [], products: [.fullGame])))
    ) {
      $0.fullGameProduct = .success(.fullGame)
    }
    await store.send(.restoreButtonTapped) {
      $0.isRestoring = true
    }

    await didRestoreCompletedTransactions.withValue { XCTAssert($0) }

    let restoreCompletedTransactionsError = NSError(domain: "", code: 1)
    storeKitObserver.continuation
      .yield(.restoreCompletedTransactionsFailed(restoreCompletedTransactionsError))

    await store.receive(
      .paymentTransaction(.restoreCompletedTransactionsFailed(restoreCompletedTransactionsError))
    ) {
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
