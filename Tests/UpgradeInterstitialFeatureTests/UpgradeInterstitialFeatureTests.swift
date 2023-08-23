import Combine
import ComposableArchitecture
import ComposableStoreKit
@_spi(Concurrency) import Dependencies
import FirstPartyMocks
import ServerConfig
import StoreKit
import UpgradeInterstitialFeature
import XCTest

@testable import ServerConfigClient

@MainActor
class UpgradeInterstitialFeatureTests: XCTestCase {
  let scheduler = RunLoop.test

  func testUpgrade() async {
    await withMainSerialExecutor {
      let dismissed = LockIsolated(false)

      let paymentAdded = ActorIsolated<String?>(nil)

      let observer = AsyncStream<StoreKitClient.PaymentTransactionObserverEvent>
        .makeStream()

      let transactions = [
        StoreKitClient.PaymentTransaction(
          error: nil,
          original: nil,
          payment: .init(
            applicationUsername: nil,
            productIdentifier: "co.pointfree.isowords_testing.full_game",
            quantity: 1,
            requestData: nil,
            simulatesAskToBuyInSandbox: false
          ),
          rawValue: nil,
          transactionDate: .mock,
          transactionIdentifier: "deadbeef",
          transactionState: .purchased
        )
      ]

      let store = TestStore(
        initialState: UpgradeInterstitial.State()
      ) {
        UpgradeInterstitial()
      } withDependencies: {
        $0.dismiss = .init { dismissed.setValue(true) }
        $0.mainRunLoop = .immediate
        $0.serverConfig.config = { .init() }
        $0.storeKit.addPayment = { await paymentAdded.setValue($0.productIdentifier) }
        $0.storeKit.observer = { observer.stream }
        $0.storeKit.fetchProducts = { _ in
          .init(
            invalidProductIdentifiers: [],
            products: [fullGameProduct]
          )
        }
      }

      let task = await store.send(.task)

      await store.receive(.fullGameProductResponse(fullGameProduct)) {
        $0.fullGameProduct = fullGameProduct
      }

      await store.receive(.timerTick) {
        $0.secondsPassedCount = 1
      }
      await store.send(.upgradeButtonTapped) {
        $0.isPurchasing = true
      }

      observer.continuation.yield(.updatedTransactions(transactions))
      await paymentAdded.withValue {
        XCTAssertNoDifference($0, "co.pointfree.isowords_testing.full_game")
      }

      await store.receive(.paymentTransaction(.updatedTransactions(transactions)))
      await store.receive(.delegate(.fullGamePurchased))

      await task.cancel()

      XCTAssert(dismissed.value)
    }
  }

  func testWaitAndDismiss() async {
    let dismissed = LockIsolated(false)
    let store = TestStore(
      initialState: UpgradeInterstitial.State()
    ) {
      UpgradeInterstitial()
    } withDependencies: {
      $0.dismiss = .init { dismissed.setValue(true) }
      $0.mainRunLoop = self.scheduler.eraseToAnyScheduler()
      $0.serverConfig.config = { .init() }
      $0.storeKit.observer = { .finished }
      $0.storeKit.fetchProducts = { _ in
        .init(invalidProductIdentifiers: [], products: [])
      }
    }

    await store.send(.task)

    await self.scheduler.advance(by: .seconds(1))
    await store.receive(.timerTick) { $0.secondsPassedCount = 1 }

    await self.scheduler.advance(by: .seconds(15))
    await store.receive(.timerTick) { $0.secondsPassedCount = 2 }
    await store.receive(.timerTick) { $0.secondsPassedCount = 3 }
    await store.receive(.timerTick) { $0.secondsPassedCount = 4 }
    await store.receive(.timerTick) { $0.secondsPassedCount = 5 }
    await store.receive(.timerTick) { $0.secondsPassedCount = 6 }
    await store.receive(.timerTick) { $0.secondsPassedCount = 7 }
    await store.receive(.timerTick) { $0.secondsPassedCount = 8 }
    await store.receive(.timerTick) { $0.secondsPassedCount = 9 }
    await store.receive(.timerTick) { $0.secondsPassedCount = 10 }

    await self.scheduler.run()

    await store.send(.maybeLaterButtonTapped)
    XCTAssert(dismissed.value)
  }

  func testMaybeLater_Dismissable() async {
    let dismissed = LockIsolated(false)
    let store = TestStore(
      initialState: UpgradeInterstitial.State(isDismissable: true)
    ) {
      UpgradeInterstitial()
    } withDependencies: {
      $0.dismiss = .init { dismissed.setValue(true) }
      $0.mainRunLoop = .immediate
      $0.serverConfig.config = { .init() }
      $0.storeKit.observer = { .finished }
      $0.storeKit.fetchProducts = { _ in
        .init(invalidProductIdentifiers: [], products: [])
      }
    }

    await store.send(.task)
    await store.send(.maybeLaterButtonTapped)
    XCTAssert(dismissed.value)
  }
}

let fullGameProduct = StoreKitClient.Product(
  downloadContentLengths: [],
  downloadContentVersion: "",
  isDownloadable: false,
  localizedDescription: "",
  localizedTitle: "",
  price: 4.99,
  priceLocale: .init(identifier: "en_US"),
  productIdentifier: "co.pointfree.isowords_testing.full_game"
)
