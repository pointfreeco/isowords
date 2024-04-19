import ComposableArchitecture
@testable import SettingsFeature
import SnapshotTesting
import Styleguide
import UserSettings
import XCTest

class SettingsViewTests: XCTestCase {
  override func setUpWithError() throws {
    try super.setUpWithError()
    try XCTSkipIf(!Styleguide.registerFonts())
    diffTool = "ksdiff"
//    isRecording = true
  }

  func testBasics() {
    assertSnapshot(
      matching: SettingsView(
        store: .init(
          initialState: .init()
        ) {
        },
        navPresentationStyle: .navigation
      ),
      as: .image(perceptualPrecision: 0.98, layout: .device(config: .iPhoneXsMax))
    )

    assertSnapshot(
      matching: SettingsView(
        store: .init(
          initialState: .init(fullGameProduct: .success(.fullGame))
        ) {
        },
        navPresentationStyle: .navigation
      ),
      as: .image(perceptualPrecision: 0.98, layout: .device(config: .iPhoneXsMax))
    )

    assertSnapshot(
      matching: SettingsView(
        store: .init(
          initialState: .init(fullGamePurchasedAt: .mock)
        ) {
        },
        navPresentationStyle: .navigation
      ),
      as: .image(perceptualPrecision: 0.98, layout: .device(config: .iPhoneXsMax))
    )
  }

  func testNotifications() {
    assertSnapshot(
      matching: NotificationsSettingsView(
        store: .init(
          initialState: .init()
        ) {
        }
      ),
      as: .image(perceptualPrecision: 0.98, layout: .device(config: .iPhoneXsMax))
    )

    @Shared(.userSettings) var userSettings = UserSettings()
    userSettings = UserSettings(enableNotifications: true)

    assertSnapshot(
      matching: NotificationsSettingsView(
        store: .init(
          initialState: .init()
        ) {
        }
      ),
      as: .image(perceptualPrecision: 0.98, layout: .device(config: .iPhoneXsMax))
    )
  }

  func testSound() {
    assertSnapshot(
      matching: SoundsSettingsView(
        store: .init(
          initialState: .init()
        ) {
        }
      ),
      as: .image(perceptualPrecision: 0.98, layout: .device(config: .iPhoneXsMax))
    )

    @Shared(.userSettings) var userSettings = UserSettings()
    userSettings = UserSettings(musicVolume: 0, soundEffectsVolume: 0)

    assertSnapshot(
      matching: SoundsSettingsView(
        store: Store(
          initialState: Settings.State()
        ) {
        }
      ),
      as: .image(perceptualPrecision: 0.98, layout: .device(config: .iPhoneXsMax))
    )
  }

  func testAppearance() {
    assertSnapshot(
      matching: AppearanceSettingsView(
        store: .init(
          initialState: .init()
        ) {
        }
      ),
      as: .image(perceptualPrecision: 0.98, layout: .device(config: .iPhoneXsMax))
    )
  }

  func testAccessibility() {
    assertSnapshot(
      matching: AccessibilitySettingsView(
        store: .init(
          initialState: .init()
        ) {
        }
      ),
      as: .image(perceptualPrecision: 0.98, layout: .device(config: .iPhoneXsMax))
    )
  }

  func testPurchases() {
    assertSnapshot(
      matching: PurchasesSettingsView(
        store: .init(
          initialState: .init()
        ) {
        }
      ),
      as: .image(perceptualPrecision: 0.98, layout: .device(config: .iPhoneXsMax))
    )

    assertSnapshot(
      matching: PurchasesSettingsView(
        store: .init(
          initialState: .init(fullGameProduct: .success(.fullGame))
        ) {
        }
      ),
      as: .image(perceptualPrecision: 0.98, layout: .device(config: .iPhoneXsMax))
    )

    assertSnapshot(
      matching: PurchasesSettingsView(
        store: .init(
          initialState: .init(fullGamePurchasedAt: .mock)
        ) {
        }
      ),
      as: .image(perceptualPrecision: 0.98, layout: .device(config: .iPhoneXsMax))
    )
  }
}
