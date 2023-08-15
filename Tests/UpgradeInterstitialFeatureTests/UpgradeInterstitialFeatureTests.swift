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
      let store = TestStore(
        initialState: UpgradeInterstitial.State()
      ) {
        UpgradeInterstitial()
      }

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

      store.dependencies.mainRunLoop = .immediate
      store.dependencies.serverConfig.config = { .init() }
      store.dependencies.storeKit.addPayment = { await paymentAdded.setValue($0.productIdentifier) }
      store.dependencies.storeKit.observer = { observer.stream }
      store.dependencies.storeKit.fetchProducts = { _ in
        .init(
          invalidProductIdentifiers: [],
          products: [fullGameProduct]
        )
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
    }
  }

  func testWaitAndDismiss() async {
    let store = TestStore(
      initialState: UpgradeInterstitial.State()
    ) {
      UpgradeInterstitial()
    }

    store.dependencies.mainRunLoop = self.scheduler.eraseToAnyScheduler()
    store.dependencies.serverConfig.config = { .init() }
    store.dependencies.storeKit.observer = { .finished }
    store.dependencies.storeKit.fetchProducts = { _ in
      .init(invalidProductIdentifiers: [], products: [])
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
    await store.receive(.delegate(.close))
  }

  func testMaybeLater_Dismissable() async {
    let store = TestStore(
      initialState: UpgradeInterstitial.State(isDismissable: true)
    ) {
      UpgradeInterstitial()
    }

    store.dependencies.mainRunLoop = .immediate
    store.dependencies.serverConfig.config = { .init() }
    store.dependencies.storeKit.observer = { .finished }
    store.dependencies.storeKit.fetchProducts = { _ in
      .init(invalidProductIdentifiers: [], products: [])
    }

    await store.send(.task)
    await store.send(.maybeLaterButtonTapped)
    await store.receive(.delegate(.close))
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
