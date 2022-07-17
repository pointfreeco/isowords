import Combine
import ComposableArchitecture
import ComposableStoreKit
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
    var paymentAdded: SKPayment?

    let observer = AsyncStream<StoreKitClient.PaymentTransactionObserverEvent>
      .streamWithContinuation()

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

    var environment = UpgradeInterstitialEnvironment.failing
    environment.mainRunLoop = .immediate
    environment.serverConfig.config = { .init() }
    environment.storeKit.addPayment = { paymentAdded = $0 }
    environment.storeKit.observerAsync = { observer.stream }
    environment.storeKit.fetchProductsAsync = { _ in
      .init(
        invalidProductIdentifiers: [],
        products: [fullGameProduct]
      )
    }

    let store = TestStore(
      initialState: .init(),
      reducer: upgradeInterstitialReducer,
      environment: environment
    )

    await store.send(.onAppear)

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
    XCTAssertNoDifference(paymentAdded?.productIdentifier, "co.pointfree.isowords_testing.full_game")

    await store.receive(.paymentTransaction(.updatedTransactions(transactions)))
    await store.receive(.delegate(.fullGamePurchased))
  }

  func testWaitAndDismiss() async {
    var environment = UpgradeInterstitialEnvironment.failing
    environment.mainRunLoop = self.scheduler.eraseToAnyScheduler()
    environment.serverConfig.config = { .init() }
    environment.storeKit.observerAsync = { .finished }
    environment.storeKit.fetchProductsAsync = { _ in
      .init(invalidProductIdentifiers: [], products: [])
    }

    let store = TestStore(
      initialState: .init(),
      reducer: upgradeInterstitialReducer,
      environment: environment
    )

    await store.send(.onAppear)

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

  func testMaybeLater_Dismissable() async  {
    var environment = UpgradeInterstitialEnvironment.failing
    environment.mainRunLoop = .immediate
    environment.serverConfig.config = { .init() }
    environment.storeKit.observerAsync = { .finished }
    environment.storeKit.fetchProductsAsync = { _ in
      .init(invalidProductIdentifiers: [], products: [])
    }

    let store = TestStore(
      initialState: .init(isDismissable: true),
      reducer: upgradeInterstitialReducer,
      environment: environment
    )

    await store.send(.onAppear)
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

extension UpgradeInterstitialEnvironment {
  static let failing = Self(
    mainRunLoop: .failing("mainRunLoop"),
    serverConfig: .failing,
    storeKit: .failing
  )
}
