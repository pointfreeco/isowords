import ComposableArchitecture
import Overture
import UpgradeInterstitialFeature
import XCTest

@testable import ServerConfig

class ShowUpgradeInterstitialEffectTests: XCTestCase {
  func testBasics() {
    var shows: [Bool] = []
    (1...20).forEach { count in
      _ = Effect.showUpgradeInterstitial(
        gameContext: .solo,
        isFullGamePurchased: false,
        serverConfig: update(.init()) {
          $0.upgradeInterstitial.playedSoloGamesTriggerCount = 10
          $0.upgradeInterstitial.soloGameTriggerEvery = 4
        },
        playedGamesCount: { .init(value: count) }
      )
      .sink(
        receiveCompletion: { _ in },
        receiveValue: { shows.append($0) }
      )
    }

    XCTAssertEqual(
      shows,
      [
        false, false, false, false, false, false, false, false, false, true,
        false, false, false, true, false, false, false, true, false, false,
      ]
    )
  }
}
