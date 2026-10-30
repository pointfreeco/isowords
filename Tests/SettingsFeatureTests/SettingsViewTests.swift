import ComposableArchitecture
import Dependencies
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

  @MainActor
  func testBasics() {
    assertSnapshot(
      matching: SettingsView(
        store: settingsStore { .init() },
        navPresentationStyle: .navigation
      ),
      as: .image(perceptualPrecision: 0.98, layout: .device(config: .iPhoneXsMax))
    )

    assertSnapshot(
      matching: SettingsView(
        store: settingsStore { .init(fullGameProduct: .success(.fullGame)) },
        navPresentationStyle: .navigation
      ),
      as: .image(perceptualPrecision: 0.98, layout: .device(config: .iPhoneXsMax))
    )

    assertSnapshot(
      matching: SettingsView(
        store: settingsStore { .init(fullGamePurchasedAt: .mock) },
        navPresentationStyle: .navigation
      ),
      as: .image(perceptualPrecision: 0.98, layout: .device(config: .iPhoneXsMax))
    )
  }

  @MainActor
  func testNotifications() {
    assertSnapshot(
      matching: NotificationsSettingsView(store: settingsStore { .init() }),
      as: .image(perceptualPrecision: 0.98, layout: .device(config: .iPhoneXsMax))
    )

    assertSnapshot(
      matching: NotificationsSettingsView(
        store: settingsStore(userSettings: UserSettings(enableNotifications: true)) { .init() }
      ),
      as: .image(perceptualPrecision: 0.98, layout: .device(config: .iPhoneXsMax))
    )
  }

  @MainActor
  func testSound() {
    assertSnapshot(
      matching: SoundsSettingsView(store: settingsStore { .init() }),
      as: .image(perceptualPrecision: 0.98, layout: .device(config: .iPhoneXsMax))
    )

    assertSnapshot(
      matching: SoundsSettingsView(
        store: settingsStore(
          userSettings: UserSettings(musicVolume: 0, soundEffectsVolume: 0)
        ) { .init() }
      ),
      as: .image(perceptualPrecision: 0.98, layout: .device(config: .iPhoneXsMax))
    )
  }

  @MainActor
  func testAppearance() {
    assertSnapshot(
      matching: AppearanceSettingsView(store: settingsStore { .init() }),
      as: .image(perceptualPrecision: 0.98, layout: .device(config: .iPhoneXsMax))
    )
  }

  @MainActor
  func testAccessibility() {
    assertSnapshot(
      matching: AccessibilitySettingsView(store: settingsStore { .init() }),
      as: .image(perceptualPrecision: 0.98, layout: .device(config: .iPhoneXsMax))
    )
  }

  @MainActor
  func testPurchases() {
    assertSnapshot(
      matching: PurchasesSettingsView(store: settingsStore { .init() }),
      as: .image(perceptualPrecision: 0.98, layout: .device(config: .iPhoneXsMax))
    )

    assertSnapshot(
      matching: PurchasesSettingsView(
        store: settingsStore { .init(fullGameProduct: .success(.fullGame)) }
      ),
      as: .image(perceptualPrecision: 0.98, layout: .device(config: .iPhoneXsMax))
    )

    assertSnapshot(
      matching: PurchasesSettingsView(
        store: settingsStore { .init(fullGamePurchasedAt: .mock) }
      ),
      as: .image(perceptualPrecision: 0.98, layout: .device(config: .iPhoneXsMax))
    )
  }
}

@MainActor
private func settingsStore(
  userSettings: UserSettings = UserSettings(),
  _ initialState: () -> Settings.State
) -> StoreOf<Settings> {
  withDependencies {
    $0.apiClient.baseUrl = { URL(string: "https://www.isowords.xyz")! }
    $0.apiClient.currentPlayer = { nil }
    $0.applicationClient.alternateIconName = { nil }
    $0.userSettings = .mock(initialUserSettings: userSettings)
  } operation: {
    Store(initialState: initialState()) {
      EmptyFeature()
    }
  }
}
