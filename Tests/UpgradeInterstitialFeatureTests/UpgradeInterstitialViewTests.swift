import ComposableArchitecture
import SnapshotTesting
import Styleguide
import UpgradeInterstitialFeature
import XCTest

class UpgradeInterstitialViewTests: XCTestCase {
  override func setUpWithError() throws {
    try super.setUpWithError()
    try XCTSkipIf(!Styleguide.registerFonts())
    SnapshotTesting.diffTool = "ksdiff"
//    isRecording = true
  }

  func testBeginning() {
    assertSnapshot(
      matching: UpgradeInterstitialView(
        store: Store(
          initialState: UpgradeInterstitial.State(
            fullGameProduct: .init(
              downloadContentLengths: [],
              downloadContentVersion: "",
              isDownloadable: false,
              localizedDescription: "Full Game",
              localizedTitle: "Full Game",
              price: 5,
              priceLocale: Locale.init(identifier: "en_US"),
              productIdentifier: "full_game"
            ),
            isDismissable: false,
            secondsPassedCount: 0
          )
        ) {
        }
      ),
      as: .image(perceptualPrecision: 0.98, layout: .device(config: .iPhoneXsMax))
    )
  }

  func testCountdownComplete() {
    assertSnapshot(
      matching: UpgradeInterstitialView(
        store: .init(
          initialState: .init(secondsPassedCount: 15, upgradeInterstitialDuration: 15)
        ) {
        }
      ),
      as: .image(perceptualPrecision: 0.98, layout: .device(config: .iPhoneXsMax))
    )
  }
}
