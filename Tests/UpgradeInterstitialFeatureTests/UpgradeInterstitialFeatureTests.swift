import Combine
import ComposableArchitecture
import ComposableStoreKit
import FirstPartyMocks
import ServerConfig
import StoreKit
import UpgradeInterstitialFeature
import XCTest

@testable import ServerConfigClient

class UpgradeInterstitialFeatureTests: XCTestCase {
  let scheduler = RunLoop.test

  func testUpgrade() {
    var paymentAdded: SKPayment?

    let observer = PassthroughSubject<StoreKitClient.PaymentTransactionObserverEvent, Never>()

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
    environment.storeKit.addPayment = { payment in
      paymentAdded = payment
      return .none
    }
    environment.storeKit.observer = observer.eraseToEffect()
    environment.storeKit.fetchProducts = { _ in
      .init(
        value: .init(
          invalidProductIdentifiers: [],
          products: [fullGameProduct]
        )
      )
    }

    let store = TestStore(
      initialState: .init(),
      reducer: upgradeInterstitialReducer,
      environment: environment
    )

    store.send(.onAppear)

    store.receive(.fullGameProductResponse(fullGameProduct)) {
      $0.fullGameProduct = fullGameProduct
    }

    store.send(.upgradeButtonTapped) {
      $0.isPurchasing = true
    }

    observer.send(.updatedTransactions(transactions))
    XCTAssertNoDifference(paymentAdded?.productIdentifier, "co.pointfree.isowords_testing.full_game")

    store.receive(.paymentTransaction(.updatedTransactions(transactions)))
    store.receive(.delegate(.fullGamePurchased))
  }

  func testWaitAndDismiss() {
    var environment = UpgradeInterstitialEnvironment.failing
    environment.mainRunLoop = self.scheduler.eraseToAnyScheduler()
    environment.serverConfig.config = { .init() }
    environment.storeKit.observer = .none
    environment.storeKit.fetchProducts = { _ in .none }

    let store = TestStore(
      initialState: .init(),
      reducer: upgradeInterstitialReducer,
      environment: environment
    )

    store.send(.onAppear)

    self.scheduler.advance(by: .seconds(1))
    store.receive(.timerTick) { $0.secondsPassedCount = 1 }

    self.scheduler.advance(by: .seconds(15))
    store.receive(.timerTick) { $0.secondsPassedCount = 2 }
    store.receive(.timerTick) { $0.secondsPassedCount = 3 }
    store.receive(.timerTick) { $0.secondsPassedCount = 4 }
    store.receive(.timerTick) { $0.secondsPassedCount = 5 }
    store.receive(.timerTick) { $0.secondsPassedCount = 6 }
    store.receive(.timerTick) { $0.secondsPassedCount = 7 }
    store.receive(.timerTick) { $0.secondsPassedCount = 8 }
    store.receive(.timerTick) { $0.secondsPassedCount = 9 }
    store.receive(.timerTick) { $0.secondsPassedCount = 10 }

    self.scheduler.run()

    store.send(.maybeLaterButtonTapped)
    store.receive(.delegate(.close))
  }

  func testMaybeLater_Dismissable() {
    var environment = UpgradeInterstitialEnvironment.failing
    environment.mainRunLoop = .immediate
    environment.serverConfig.config = { .init() }
    environment.storeKit.observer = .none
    environment.storeKit.fetchProducts = { _ in .none }

    let store = TestStore(
      initialState: .init(isDismissable: true),
      reducer: upgradeInterstitialReducer,
      environment: environment
    )

    store.send(.onAppear)
    store.send(.maybeLaterButtonTapped)
    store.receive(.delegate(.close))
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
