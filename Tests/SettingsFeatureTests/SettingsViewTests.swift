import ComposableArchitecture
@testable import SettingsFeature
import SnapshotTesting
import Styleguide
import UserSettingsClient
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

    assertSnapshot(
      matching: NotificationsSettingsView(
        store: .init(
          initialState: .init(
            enableNotifications: true
          )
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

    assertSnapshot(
      matching: SoundsSettingsView(
        store: Store(
          initialState: Settings.State()
        ) {
        } withDependencies: {
          $0.userSettings = .mock(
            initialUserSettings: UserSettings(musicVolume: 0, soundEffectsVolume: 0)
          )
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
