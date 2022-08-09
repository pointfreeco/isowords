import ComposableArchitecture
import Overture
import UpgradeInterstitialFeature
import XCTest

@testable import ServerConfig

class ShowUpgradeInterstitialEffectTests: XCTestCase {
  func testBasics() {
    let shows = (1...20).map { count in
      shouldShowInterstitial(
        gamePlayedCount: count,
        gameContext: .solo,
        serverConfig: update(.init()) {
          $0.upgradeInterstitial.playedSoloGamesTriggerCount = 10
          $0.upgradeInterstitial.soloGameTriggerEvery = 4
        }
      )
    }

    XCTAssertNoDifference(
      shows,
      [
        false, false, false, false, false, false, false, false, false, true,
        false, false, false, true,
        false, false, false, true,
        false, false,
      ]
    )
  }
}
