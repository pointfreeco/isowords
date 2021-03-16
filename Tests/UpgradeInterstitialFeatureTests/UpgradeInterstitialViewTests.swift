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
          initialState: .init(),
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
