@testable import SettingsFeature
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

  func testNotifications() {
    assertSnapshot(
      matching: NotificationsSettingsView(
        store: .init(
          initialState: .init(),
          reducer: .empty,
          environment: ()
        )
      ),
      as: .image(layout: .device(config: .iPhoneXsMax))
    )

    assertSnapshot(
      matching: NotificationsSettingsView(
        store: .init(
          initialState: .init(
            enableNotifications: true
          ),
          reducer: .empty,
          environment: ()
        )
      ),
      as: .image(layout: .device(config: .iPhoneXsMax))
    )
  }

  func testSound() {
    assertSnapshot(
      matching: SoundsSettingsView(
        store: .init(
          initialState: .init(),
          reducer: .empty,
          environment: ()
        )
      ),
      as: .image(layout: .device(config: .iPhoneXsMax))
    )
  }

  func testAppearance() {
    assertSnapshot(
      matching: AppearanceSettingsView(
        store: .init(
          initialState: .init(),
          reducer: .empty,
          environment: ()
        )
      ),
      as: .image(layout: .device(config: .iPhoneXsMax))
    )
  }

  func testAccessibility() {
    assertSnapshot(
      matching: AccessibilitySettingsView(
        store: .init(
          initialState: .init(),
          reducer: .empty,
          environment: ()
        )
      ),
      as: .image(layout: .device(config: .iPhoneXsMax))
    )
  }

  func testPurchases() {
    assertSnapshot(
      matching: PurchasesSettingsView(
        store: .init(
          initialState: .init(),
          reducer: .empty,
          environment: ()
        )
      ),
      as: .image(layout: .device(config: .iPhoneXsMax))
    )

    assertSnapshot(
      matching: PurchasesSettingsView(
        store: .init(
          initialState: .init(fullGameProduct: .success(.fullGame)),
          reducer: .empty,
          environment: ()
        )
      ),
      as: .image(layout: .device(config: .iPhoneXsMax))
    )

    assertSnapshot(
      matching: PurchasesSettingsView(
        store: .init(
          initialState: .init(fullGamePurchasedAt: .mock),
          reducer: .empty,
          environment: ()
        )
      ),
      as: .image(layout: .device(config: .iPhoneXsMax))
    )
  }
}
