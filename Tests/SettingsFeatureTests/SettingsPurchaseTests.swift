import Combine
import ComposableArchitecture
import ComposableStoreKit
import ConcurrencyExtras
import CustomDump
@_spi(Concurrency) import Dependencies
import FileClient
import LocalDatabaseClient
import SharedModels
import XCTest

@testable import ServerConfig
@testable import SettingsFeature

fileprivate extension DependencyValues {
  mutating func setUpDefaults() {
    self.apiClient.baseUrl = { URL(string: "http://localhost:9876")! }
    self.applicationClient.alternateIconName = { nil }
    self.build.number = { 42 }
    self.database.fetchStats = { try await Task.never() }
    self.mainQueue = .immediate
    self.fileClient.save = { @Sendable _, _ in }
    self.userNotifications.getNotificationSettings = {
      (try? await Task.never()) ?? .init(authorizationStatus: .notDetermined)
    }
    self.userSettings = .mock()
  }
}

class SettingsPurchaseTests: XCTestCase {
  override func invokeTest() {
    withMainSerialExecutor {
      super.invokeTest()
    }
  }

  @MainActor
  func testUpgrade_HappyPath() async throws {
    let didAddPaymentProductIdentifier = ActorIsolated<String?>(nil)
    let storeKitObserver = AsyncStream<StoreKitClient.PaymentTransactionObserverEvent>
      .makeStream()

    let store = withDependencies {
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
    } operation: {
      TestStore(initialState: Settings.State()) {
        Settings()
      } changes: {
        $0.buildNumber = 42
      }
    }

    await Task.megaYield()
    store.expect {
      $0.fullGameProduct = .success(.fullGame)
    }
    await store.send(.tappedProduct(.fullGame)) {
      $0.isPurchasing = true
    }?.value
    await didAddPaymentProductIdentifier.withValue {
      expectNoDifference($0, "xyz.isowords.full_game")
    }
    storeKitObserver.continuation.yield(.updatedTransactions([.purchasing]))
    storeKitObserver.continuation.yield(.updatedTransactions([.purchased]))
    storeKitObserver.continuation.yield(.removedTransactions([.purchased]))

    await store.receive(\.paymentTransaction.updatedTransactions, timeout: .seconds(1))
    await store.receive(\.paymentTransaction.updatedTransactions, timeout: .seconds(1))
    await store.receive(\.paymentTransaction.removedTransactions, timeout: .seconds(1)) {
      $0.fullGamePurchasedAt = .mock
      $0.isPurchasing = false
    }

    await store.dismount()
  }

  @MainActor
  func testRestore_HappyPath() async throws {
    let didRestoreCompletedTransactions = ActorIsolated(false)
    let storeKitObserver = AsyncStream<StoreKitClient.PaymentTransactionObserverEvent>
      .makeStream()
    let store = withDependencies {
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
    } operation: {
      TestStore(initialState: Settings.State()) {
        Settings()
      } changes: {
        $0.buildNumber = 42
      }
    }

    await Task.megaYield()
    store.expect {
      $0.fullGameProduct = .success(.fullGame)
    }
    await store.send(.restoreButtonTapped) {
      $0.isRestoring = true
    }?.value

    await didRestoreCompletedTransactions.withValue { expectNoDifference($0, true) }
    storeKitObserver.continuation.yield(.updatedTransactions([.restored]))
    storeKitObserver.continuation.yield(.removedTransactions([.restored]))
    storeKitObserver.continuation.yield(
      .restoreCompletedTransactionsFinished(transactions: [.restored]))

    await store.receive(\.paymentTransaction.updatedTransactions, timeout: .seconds(1))
    await store.receive(\.paymentTransaction.removedTransactions, timeout: .seconds(1)) {
      $0.fullGamePurchasedAt = .mock
      $0.isRestoring = false
    }
    await store.receive(
      \.paymentTransaction.restoreCompletedTransactionsFinished, timeout: .seconds(1)
    )

    await store.dismount()
  }

  @MainActor
  func testRestore_NoPurchasesPath() async throws {
    let didRestoreCompletedTransactions = ActorIsolated(false)
    let storeKitObserver = AsyncStream<StoreKitClient.PaymentTransactionObserverEvent>
      .makeStream()
    let store = withDependencies {
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
    } operation: {
      TestStore(initialState: Settings.State()) {
        Settings()
      } changes: {
        $0.buildNumber = 42
      }
    }

    await Task.megaYield()
    store.expect {
      $0.fullGameProduct = .success(.fullGame)
    }
    await store.send(.restoreButtonTapped) {
      $0.isRestoring = true
    }?.value

    await didRestoreCompletedTransactions.withValue { expectNoDifference($0, true) }
    storeKitObserver.continuation.yield(.restoreCompletedTransactionsFinished(transactions: []))

    await store.receive(
      \.paymentTransaction.restoreCompletedTransactionsFinished, timeout: .seconds(1)
    ) {
      $0.isRestoring = false
      $0.destination = .noRestoredPurchasesAlert
    }

    await store.dismount()
  }

  @MainActor
  func testRestore_ErrorPath() async throws {
    let didRestoreCompletedTransactions = ActorIsolated(false)
    let storeKitObserver = AsyncStream<StoreKitClient.PaymentTransactionObserverEvent>
      .makeStream()
    let store = withDependencies {
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
    } operation: {
      TestStore(initialState: Settings.State()) {
        Settings()
      } changes: {
        $0.buildNumber = 42
      }
    }

    await Task.megaYield()
    store.expect {
      $0.fullGameProduct = .success(.fullGame)
    }
    await store.send(.restoreButtonTapped) {
      $0.isRestoring = true
    }?.value

    await didRestoreCompletedTransactions.withValue { XCTAssert($0) }

    let restoreCompletedTransactionsError = NSError(domain: "", code: 1)
    storeKitObserver.continuation
      .yield(.restoreCompletedTransactionsFailed(restoreCompletedTransactionsError))

    await store.receive(
      \.paymentTransaction.restoreCompletedTransactionsFailed, timeout: .seconds(1)
    ) {
      $0.isRestoring = false
      $0.destination = .restoredPurchasesFailedAlert
    }

    await store.dismount()
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
