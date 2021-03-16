import SettingsFeature
import SnapshotTesting
import Styleguide
import XCTest

class SettingsViewTests: XCTestCase {
  override func setUpWithError() throws {
    try super.setUpWithError()
    try XCTSkipIf(!Styleguide.registerFonts())
//    isRecording = true
  }

  func testBasics() {
    assertSnapshot(
      matching: SettingsView(
        store: .init(
          initialState: .init(),
          reducer: .empty,
          environment: ()
        ),
        navPresentationStyle: .navigation
      ),
      as: .image(layout: .device(config: .iPhoneXsMax))
    )

    assertSnapshot(
      matching: SettingsView(
        store: .init(
          initialState: .init(fullGameProduct: .success(.fullGame)),
          reducer: .empty,
          environment: ()
        ),
        navPresentationStyle: .navigation
      ),
      as: .image(layout: .device(config: .iPhoneXsMax))
    )

    assertSnapshot(
      matching: SettingsView(
        store: .init(
          initialState: .init(fullGamePurchasedAt: .mock),
          reducer: .empty,
          environment: ()
        ),
        navPresentationStyle: .navigation
      ),
      as: .image(layout: .device(config: .iPhoneXsMax))
    )
  }
}
