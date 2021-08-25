import Combine
import ComposableArchitecture
import ComposableStoreKit
import SharedModels
import XCTest

@testable import ServerConfig
@testable import SettingsFeature

class SettingsPurchaseTests: XCTestCase {
  var defaultEnvironment: SettingsEnvironment {
    var environment = SettingsEnvironment.failing
    environment.apiClient.baseUrl = { URL(string: "http://localhost:9876")! }
    environment.applicationClient.alternateIconName = { nil }
    environment.build.number = { 42 }
    environment.mainQueue = .immediate
    environment.backgroundQueue = .immediate
    environment.fileClient.save = { _, _ in .none }
    environment.userNotifications.getNotificationSettings = .none
    environment.userNotifications.requestAuthorization = { _ in .init(value: false) }
    return environment
  }

  func testUpgrade_HappyPath() throws {
    var didAddPaymentProductIdentifier: String? = nil
    let storeKitObserver = PassthroughSubject<
      StoreKitClient.PaymentTransactionObserverEvent, Never
    >()

    var environment = self.defaultEnvironment
    environment.serverConfig.config = {
      .init(productIdentifiers: .init(fullGame: "xyz.isowords.full_game"))
    }
    environment.apiClient.currentPlayer = { .some(.blobWithoutPurchase) }
    environment.apiClient.refreshCurrentPlayer = { .init(value: .blobWithPurchase) }
    environment.storeKit.addPayment = { payment in
      .fireAndForget {
        didAddPaymentProductIdentifier = payment.productIdentifier
      }
    }
    environment.storeKit.fetchProducts = { _ in
      .init(value: .init(invalidProductIdentifiers: [], products: [.fullGame]))
    }
    environment.storeKit.observer = storeKitObserver.eraseToEffect()

    let store = TestStore(
      initialState: SettingsState(),
      reducer: settingsReducer,
      environment: environment
    )

    store.send(.onAppear) {
      $0.buildNumber = 42
      $0.developer.currentBaseUrl = .localhost
    }
    store.receive(
      .productsResponse(.success(.init(invalidProductIdentifiers: [], products: [.fullGame])))
    ) {
      $0.fullGameProduct = .success(.fullGame)
    }
    store.send(.tappedProduct(.fullGame)) {
      $0.isPurchasing = true
    }
    XCTAssertNoDifference(didAddPaymentProductIdentifier, "xyz.isowords.full_game")
    storeKitObserver.send(.updatedTransactions([.purchasing]))
    storeKitObserver.send(.updatedTransactions([.purchased]))
    storeKitObserver.send(.removedTransactions([.purchased]))

    store.receive(SettingsAction.paymentTransaction(.updatedTransactions([.purchasing])))
    store.receive(SettingsAction.paymentTransaction(.updatedTransactions([.purchased])))
    store.receive(SettingsAction.paymentTransaction(.removedTransactions([.purchased]))) {
      $0.isPurchasing = false
    }
    store.receive(SettingsAction.currentPlayerRefreshed(.success(.blobWithPurchase))) {
      $0.fullGamePurchasedAt = .mock
    }
    store.send(.onDismiss)
  }

  func testRestore_HappyPath() throws {
    var didRestoreCompletedTransactions = false
    let storeKitObserver = PassthroughSubject<
      StoreKitClient.PaymentTransactionObserverEvent, Never
    >()

    var environment = self.defaultEnvironment
    environment.serverConfig.config = {
      .init(productIdentifiers: .init(fullGame: "xyz.isowords.full_game"))
    }
    environment.apiClient.currentPlayer = { .some(.blobWithoutPurchase) }
    environment.apiClient.refreshCurrentPlayer = { .init(value: .blobWithPurchase) }
    environment.storeKit.restoreCompletedTransactions = {
      .fireAndForget {
        didRestoreCompletedTransactions = true
      }
    }
    environment.storeKit.fetchProducts = { _ in
      .init(value: .init(invalidProductIdentifiers: [], products: [.fullGame]))
    }
    environment.storeKit.observer = storeKitObserver.eraseToEffect()

    let store = TestStore(
      initialState: SettingsState(),
      reducer: settingsReducer,
      environment: environment
    )

    store.send(.onAppear) {
      $0.buildNumber = 42
      $0.developer.currentBaseUrl = .localhost
    }
    store.receive(
      .productsResponse(.success(.init(invalidProductIdentifiers: [], products: [.fullGame])))
    ) {
      $0.fullGameProduct = .success(.fullGame)
    }
    store.send(.restoreButtonTapped) {
      $0.isRestoring = true
    }

    XCTAssertNoDifference(didRestoreCompletedTransactions, true)
    storeKitObserver.send(.updatedTransactions([.restored]))
    storeKitObserver.send(.removedTransactions([.restored]))
    storeKitObserver.send(.restoreCompletedTransactionsFinished(transactions: [.restored]))

    store.receive(SettingsAction.paymentTransaction(.updatedTransactions([.restored])))
    store.receive(SettingsAction.paymentTransaction(.removedTransactions([.restored])))
    store.receive(SettingsAction.currentPlayerRefreshed(.success(.blobWithPurchase))) {
      $0.isRestoring = false
      $0.fullGamePurchasedAt = .mock
    }
    store.receive(SettingsAction.paymentTransaction(.restoreCompletedTransactionsFinished(transactions: [.restored])))
    store.send(.onDismiss)
  }

  func testRestore_NoPurchasesPath() throws {
    var didRestoreCompletedTransactions = false
    let storeKitObserver = PassthroughSubject<
      StoreKitClient.PaymentTransactionObserverEvent, Never
    >()

    var environment = self.defaultEnvironment
    environment.serverConfig.config = {
      .init(productIdentifiers: .init(fullGame: "xyz.isowords.full_game"))
    }
    environment.apiClient.currentPlayer = { .some(.blobWithoutPurchase) }
    environment.apiClient.refreshCurrentPlayer = { .init(value: .blobWithoutPurchase) }
    environment.storeKit.restoreCompletedTransactions = {
      .fireAndForget {
        didRestoreCompletedTransactions = true
      }
    }
    environment.storeKit.fetchProducts = { _ in
      .init(value: .init(invalidProductIdentifiers: [], products: [.fullGame]))
    }
    environment.storeKit.observer = storeKitObserver.eraseToEffect()

    let store = TestStore(
      initialState: SettingsState(),
      reducer: settingsReducer,
      environment: environment
    )

    store.send(.onAppear) {
      $0.buildNumber = 42
      $0.developer.currentBaseUrl = .localhost
    }
    store.receive(
      .productsResponse(.success(.init(invalidProductIdentifiers: [], products: [.fullGame])))
    ) {
      $0.fullGameProduct = .success(.fullGame)
    }
    store.send(.restoreButtonTapped) {
      $0.isRestoring = true
    }

    XCTAssertNoDifference(didRestoreCompletedTransactions, true)
    storeKitObserver.send(.restoreCompletedTransactionsFinished(transactions: []))

    store.receive(SettingsAction.paymentTransaction(.restoreCompletedTransactionsFinished(transactions: []))) {
      $0.isRestoring = false
      $0.alert = .noRestoredPurchases
    }

    store.send(.onDismiss)
  }

  func testRestore_ErrorPath() throws {
    var didRestoreCompletedTransactions = false
    let storeKitObserver = PassthroughSubject<
      StoreKitClient.PaymentTransactionObserverEvent, Never
    >()

    var environment = self.defaultEnvironment
    environment.serverConfig.config = {
      .init(productIdentifiers: .init(fullGame: "xyz.isowords.full_game"))
    }
    environment.apiClient.currentPlayer = { .some(.blobWithoutPurchase) }
    environment.apiClient.refreshCurrentPlayer = { .init(value: .blobWithoutPurchase) }
    environment.storeKit.restoreCompletedTransactions = {
      .fireAndForget {
        didRestoreCompletedTransactions = true
      }
    }
    environment.storeKit.fetchProducts = { _ in
      .init(value: .init(invalidProductIdentifiers: [], products: [.fullGame]))
    }
    environment.storeKit.observer = storeKitObserver.eraseToEffect()

    let store = TestStore(
      initialState: SettingsState(),
      reducer: settingsReducer,
      environment: environment
    )

    store.send(.onAppear) {
      $0.buildNumber = 42
      $0.developer.currentBaseUrl = .localhost
    }
    store.receive(
      .productsResponse(.success(.init(invalidProductIdentifiers: [], products: [.fullGame])))
    ) {
      $0.fullGameProduct = .success(.fullGame)
    }
    store.send(.restoreButtonTapped) {
      $0.isRestoring = true
    }

    XCTAssertNoDifference(didRestoreCompletedTransactions, true)

    let restoreCompletedTransactionsError = NSError(domain: "", code: 1)
    storeKitObserver.send(.restoreCompletedTransactionsFailed(restoreCompletedTransactionsError))

    store.receive(SettingsAction.paymentTransaction(.restoreCompletedTransactionsFailed(restoreCompletedTransactionsError))) {
      $0.isRestoring = false
      $0.alert = .restoredPurchasesFailed
    }

    store.send(.onDismiss)
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
