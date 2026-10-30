import ComposableArchitecture
import CustomDump
import ComposableStoreKit
@_spi(Concurrency) import Dependencies
import ConcurrencyExtras
import Dependencies
import FirstPartyMocks
import ServerConfig
import StoreKit
import UpgradeInterstitialFeature
import XCTest

@testable import ServerConfigClient

class UpgradeInterstitialFeatureTests: XCTestCase {
  let clock = TestClock<Duration>()

  @MainActor
  func testUpgrade() async {
    await withMainSerialExecutor {
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

      let store = withDependencies {
        $0.serverConfig.config = { .init() }
        $0.storeKit.addPayment = {
          let productIdentifier = $0.productIdentifier
          await paymentAdded.setValue(productIdentifier)
        }
        $0.storeKit.observer = { observer.stream }
        $0.storeKit.fetchProducts = { _ in
          .init(
            invalidProductIdentifiers: [],
            products: [fullGameProduct]
          )
        }
      } operation: {
        TestStore(initialState: Presenter.State(interstitial: UpgradeInterstitial.State())) {
          Presenter()
        }
      }

      await Task.megaYield()
      store.expect {
        $0.interstitial?.fullGameProduct = fullGameProduct
        $0.interstitial?.secondsPassedCount = 1
      }

      await store.send(.interstitial(.upgradeButtonTapped)) {
        $0.interstitial?.isPurchasing = true
      }?.value
      await paymentAdded.withValue {
        expectNoDifference($0, "co.pointfree.isowords_testing.full_game")
      }

      observer.continuation.yield(.updatedTransactions(transactions))

      await store.receive(
        \.interstitial.paymentTransaction.updatedTransactions, timeout: .seconds(1)
      ) {
        $0.didPurchaseFullGame = true
        $0.interstitial = nil
      }
    }
  }

  @MainActor
  func testWaitAndDismiss() async {
    let store = withDependencies {
      $0.serverConfig.config = { .init() }
      $0.storeKit.observer = { .finished }
      $0.storeKit.fetchProducts = { _ in
        .init(invalidProductIdentifiers: [], products: [])
      }
    } operation: {
      TestStore(initialState: UpgradeInterstitial.State()) {
        UpgradeInterstitial()
          .environment(\.continuousClock, self.clock)
      }
    }

    await self.clock.advance(by: .seconds(1))
    store.expect { $0.secondsPassedCount = 1 }

    await self.clock.advance(by: .seconds(15))
    store.expect { $0.secondsPassedCount = 10 }

    await self.clock.run()

    await store.send(.maybeLaterButtonTapped)?.value
    XCTAssertFalse(store.isPresented)
  }

  @MainActor
  func testMaybeLater_Dismissable() async {
    let store = withDependencies {
      $0.serverConfig.config = { .init() }
      $0.storeKit.observer = { .finished }
      $0.storeKit.fetchProducts = { _ in
        .init(invalidProductIdentifiers: [], products: [])
      }
    } operation: {
      TestStore(initialState: UpgradeInterstitial.State(isDismissable: true)) {
        UpgradeInterstitial()
      }
    }

    await store.mountTask?.value
    await store.send(.maybeLaterButtonTapped)?.value
    XCTAssertFalse(store.isPresented)
  }
}

@Feature
private struct Presenter {
  struct State {
    var didPurchaseFullGame = false
    var interstitial: UpgradeInterstitial.State?
  }
  enum Action {
    case interstitial(UpgradeInterstitial.Action)
  }
  var body: some Feature {
    EmptyFeature()
      .ifLet(\.interstitial) {
        UpgradeInterstitial()
      }
      .onEvent(UpgradeInterstitial.FullGamePurchased.self) { _, state in
        state.didPurchaseFullGame = true
      }
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
