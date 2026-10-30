import ApiClient
import Combine
import ComposableArchitecture
import ComposableUserNotifications
@_spi(Concurrency) import Dependencies
import ConcurrencyExtras
import CustomDump
import Dependencies
import LocalDatabaseClient
import Overture
import SharedModels
import TestHelpers
import UserDefaultsClient
import UserNotifications
import UserSettingsClient
import XCTest

@testable import SettingsFeature

extension DependencyValues {
  fileprivate mutating func setUpDefaults() {
    self.apiClient.baseUrl = { URL(string: "http://localhost:9876")! }
    self.apiClient.currentPlayer = { .some(.init(appleReceipt: .mock, player: .blob)) }
    self.applicationClient.alternateIconName = { nil }
    self.build.number = { 42 }
    self.database.fetchStats = { try await Task.never() }
    self.mainQueue = .immediate
    self.fileClient.save = { @Sendable _, _ in }
    self.serverConfig.config = { .init() }
    self.storeKit.fetchProducts = { _ in
      .init(invalidProductIdentifiers: [], products: [])
    }
    self.storeKit.observer = { .finished }
    self.userNotifications.getNotificationSettings = {
      (try? await Task.never()) ?? .init(authorizationStatus: .notDetermined)
    }
    self.userSettings = .mock()
  }
}

@MainActor
private func makeStore(
  file: StaticString = #filePath,
  line: UInt = #line,
  _ updateValues: (inout DependencyValues) -> Void = { _ in }
) -> TestStore<Settings> {
  withDependencies {
    $0.setUpDefaults()
    updateValues(&$0)
  } operation: {
    TestStore(
      initialState: Settings.State(),
      feature: { Settings() },
      changes: {
        $0.buildNumber = 42
        $0.fullGamePurchasedAt = .mock
      },
      filePath: file,
      line: line
    )
  }
}

class SettingsFeatureTests: XCTestCase {
  override func invokeTest() {
    withMainSerialExecutor {
      super.invokeTest()
    }
  }

  @MainActor
  func testUserSettingsBackwardsDecodability() {
    expectNoDifference(
      try JSONDecoder().decode(UserSettings.self, from: Data("{}".utf8)),
      UserSettings()
    )

    let partialJson = """
      {
        "appIcon": "icon-1",
        "colorScheme": "dark",
        "enableGyroMotion": false,
        "enableHaptics": false,
        "musicVolume": 0.25,
        "soundEffectsVolume": 0.5,
      }
      """
    expectNoDifference(
      try JSONDecoder().decode(UserSettings.self, from: Data(partialJson.utf8)),
      UserSettings(
        appIcon: .icon1,
        colorScheme: .dark,
        enableGyroMotion: false,
        enableHaptics: false,
        musicVolume: 0.25,
        soundEffectsVolume: 0.5
      )
    )
  }

  // MARK: - Notifications

  @MainActor
  func testEnableNotifications_NotDetermined_GrantAuthorization() async {
    let didRegisterForRemoteNotifications = ActorIsolated(false)

    let store = makeStore {
      $0.userNotifications.getNotificationSettings = {
        .init(authorizationStatus: .notDetermined)
      }
      $0.userNotifications.requestAuthorization = { _ in true }
      $0.remoteNotifications.register = {
        await didRegisterForRemoteNotifications.setValue(true)
      }
    }

    await Task.megaYield()
    store.expect {
      $0.userNotificationSettings = .init(authorizationStatus: .notDetermined)
    }

    await store.send(.enableNotificationsToggled(true)) {
      $0.userSettings.enableNotifications = true
    }?.value

    await didRegisterForRemoteNotifications.withValue { XCTAssert($0) }

    await store.dismount()
  }

  @MainActor
  func testEnableNotifications_NotDetermined_DenyAuthorization() async {
    let store = makeStore {
      $0.userNotifications.getNotificationSettings = {
        .init(authorizationStatus: .notDetermined)
      }
      $0.userNotifications.requestAuthorization = { _ in false }
    }

    await Task.megaYield()
    store.expect {
      $0.userNotificationSettings = .init(authorizationStatus: .notDetermined)
    }

    await store.send(.enableNotificationsToggled(true)) {
      $0.userSettings.enableNotifications = true
    }?.value
    store.expect {
      $0.userSettings.enableNotifications = false
    }

    await store.dismount()
  }

  @MainActor
  func testNotifications_PreviouslyGranted() async {
    let didRegisterForRemoteNotifications = ActorIsolated(false)
    let store = makeStore {
      $0.userNotifications.getNotificationSettings = {
        .init(authorizationStatus: .authorized)
      }
      $0.remoteNotifications.register = {
        await didRegisterForRemoteNotifications.setValue(true)
      }
    }

    await Task.megaYield()
    store.expect {
      $0.userSettings.enableNotifications = true
      $0.userNotificationSettings = .init(authorizationStatus: .authorized)
    }
    await didRegisterForRemoteNotifications.withValue {
      XCTAssertFalse(
        $0,
        "Registered for remote notifications without a user-initiated notifications toggle"
      )
    }

    await store.send(.enableNotificationsToggled(false)) {
      $0.userSettings.enableNotifications = false
    }?.value

    await store.dismount()
  }

  @MainActor
  func testNotifications_PreviouslyDenied() async {
    let openedUrl = ActorIsolated<URL?>(nil)
    let store = makeStore {
      $0.applicationClient.openSettingsURLString = {
        "settings:isowords//isowords/settings"
      }
      $0.applicationClient.open = { url, _ in
        await openedUrl.setValue(url)
        return true
      }
      $0.userNotifications.getNotificationSettings = {
        .init(authorizationStatus: .denied)
      }
    }

    await Task.megaYield()
    store.expect {
      $0.userNotificationSettings = .init(authorizationStatus: .denied)
    }

    store.send(.enableNotificationsToggled(true)) {
      $0.destination = snap(
        Settings.Destination.State.userNotificationAuthorizationDeniedAlert(.init())
      )
    }

    await store.send(
      .destination(.userNotificationAuthorizationDeniedAlert(.openSettingsButtonTapped))
    ) {
      $0.destination = nil
    }?.value

    await openedUrl.withValue {
      expectNoDifference($0, URL(string: "settings:isowords//isowords/settings")!)
    }

    await store.dismount()
  }

  @MainActor
  func testNotifications_RemoteSettingsUpdates() async {
    let userSettings = UserSettings(sendDailyChallengeReminder: false)
    let didUpdate = LockIsolated(false)
    let updatedBlobWithPurchase = update(CurrentPlayerEnvelope.blobWithPurchase) {
      $0.player.sendDailyChallengeReminder = false
    }

    let store = makeStore {
      $0.apiClient.refreshCurrentPlayer = {
        didUpdate.value ? updatedBlobWithPurchase : .blobWithPurchase
      }
      $0.apiClient.override(
        route: .push(
          .updateSetting(.init(notificationType: .dailyChallengeEndsSoon, sendNotifications: false))
        ),
        withResponse: {
          didUpdate.withValue { $0 = true }
          return try await OK([:] as [String: Any])
        }
      )
      $0.userNotifications.getNotificationSettings = {
        .init(authorizationStatus: .authorized)
      }
      $0.remoteNotifications.register = {}
      $0.userSettings = .mock(initialUserSettings: userSettings)
    }
    XCTAssertEqual(store.userSettings.sendDailyChallengeReminder, true)

    await Task.megaYield()
    store.expect {
      $0.userNotificationSettings = .init(authorizationStatus: .authorized)
      $0.userSettings.enableNotifications = true
    }

    await store.send(.dailyChallengeReminderToggled(false)) {
      $0.userSettings.sendDailyChallengeReminder = false
    }?.value
    XCTAssert(didUpdate.value)

    await store.dismount()
  }

  // MARK: - Sounds

  @MainActor
  func testSetMusicVolume() async {
    let setMusicVolume = ActorIsolated<Float?>(nil)
    let store = makeStore {
      $0.audioPlayer.setGlobalVolumeForMusic = { await setMusicVolume.setValue($0) }
    }

    await store.modify {
      $0.userSettings.musicVolume = 0.5
    }?.value

    await setMusicVolume.withValue { expectNoDifference($0, 0.5) }

    await store.dismount()
  }

  @MainActor
  func testSetSoundEffectsVolume() async {
    let setSoundEffectsVolume = ActorIsolated<Float?>(nil)
    let store = makeStore {
      $0.audioPlayer.setGlobalVolumeForSoundEffects = {
        await setSoundEffectsVolume.setValue($0)
      }
    }

    await store.modify {
      $0.userSettings.soundEffectsVolume = 0.5
    }?.value

    await setSoundEffectsVolume.withValue { expectNoDifference($0, 0.5) }

    await store.dismount()
  }

  // MARK: - Appearance

  @MainActor
  func testSetColorScheme() async {
    let overriddenUserInterfaceStyle = ActorIsolated<UIUserInterfaceStyle?>(nil)
    let store = makeStore {
      $0.applicationClient.setUserInterfaceStyle = {
        await overriddenUserInterfaceStyle.setValue($0)
      }
    }

    await store.modify {
      $0.userSettings.colorScheme = .light
    }?.value
    await overriddenUserInterfaceStyle.withValue { expectNoDifference($0, .light) }

    await store.modify {
      $0.userSettings.colorScheme = .system
    }?.value
    await overriddenUserInterfaceStyle.withValue { expectNoDifference($0, .unspecified) }

    await store.dismount()
  }

  @MainActor
  func testSetAppIcon() async {
    let overriddenIconName = ActorIsolated<String?>(nil)
    let store = makeStore {
      $0.applicationClient.setAlternateIconName = {
        await overriddenIconName.setValue($0)
      }
    }

    await store.modify {
      $0.userSettings.appIcon = .icon2
    }?.value
    await overriddenIconName.withValue { expectNoDifference($0, "icon-2") }

    await store.dismount()
  }

  @MainActor
  func testUnsetAppIcon() async {
    let overriddenIconName = ActorIsolated<String?>("icon-2")
    let store = makeStore {
      $0.applicationClient.alternateIconName = { "icon-2" }
      $0.applicationClient.setAlternateIconName = {
        await overriddenIconName.setValue($0)
      }
    }
    XCTAssertEqual(store.userSettings.appIcon, .icon2)

    await store.modify {
      $0.userSettings.appIcon = nil
    }?.value
    await overriddenIconName.withValue { XCTAssertNil($0) }

    await store.dismount()
  }

  // MARK: - Developer

  @MainActor
  func testSetApiBaseUrl() async {
    let setBaseUrl = ActorIsolated<URL?>(nil)
    let didLogout = ActorIsolated(false)
    let store = makeStore {
      $0.apiClient.logout = { await didLogout.setValue(true) }
      $0.apiClient.setBaseUrl = { await setBaseUrl.setValue($0) }
    }
    XCTAssertEqual(store.developer.currentBaseUrl, .localhost)

    await store.modify {
      $0.developer.currentBaseUrl = .staging
    }?.value
    await setBaseUrl.withValue {
      expectNoDifference($0, URL(string: "https://isowords-staging.herokuapp.com")!)
    }
    await didLogout.withValue { XCTAssert($0) }

    await store.dismount()
  }

  @MainActor
  func testToggleEnableGyroMotion() async {
    let store = makeStore {
      $0.userSettings = .mock(initialUserSettings: UserSettings(enableGyroMotion: true))
    }

    await store.modify {
      $0.userSettings.enableGyroMotion = false
    }?.value
    await store.modify {
      $0.userSettings.enableGyroMotion = true
    }?.value

    await store.dismount()
  }

  @MainActor
  func testToggleEnableHaptics() async {
    let store = makeStore {
      $0.userSettings = .mock(initialUserSettings: UserSettings(enableHaptics: true))
    }

    await store.modify {
      $0.userSettings.enableHaptics = false
    }?.value
    await store.modify {
      $0.userSettings.enableHaptics = true
    }?.value

    await store.dismount()
  }
}
