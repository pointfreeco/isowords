import SnapshotTesting
import Styleguide
import UpgradeInterstitialFeature
import XCTest

class UpgradeInterstitialViewTests: XCTestCase {
  override func setUpWithError() throws {
    try super.setUpWithError()
    try XCTSkipIf(!Styleguide.registerFonts())
//    isRecording = true
  }

  func testBeginning() {
    assertSnapshot(
      matching: UpgradeInterstitialView(
        store: .init(
          initialState: .init(
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
            isDismissable: true,
            secondsPassedCount: 0
          ),
          reducer: .empty,
          environment: ()
        )
      ),
      as: .image(layout: .device(config: .iPhoneXsMax))
    )
  }

  func testCountdownComplete() {
    assertSnapshot(
      matching: UpgradeInterstitialView(
        store: .init(
          initialState: .init(secondsPassedCount: 15, upgradeInterstitialDuration: 15),
          reducer: .empty,
          environment: ()
        )
      ),
      as: .image(layout: .device(config: .iPhoneXsMax))
    )
  }
}
