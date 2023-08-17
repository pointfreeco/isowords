import ApiClient
import Combine
import ComposableArchitecture
import ComposableUserNotifications
@_spi(Concurrency) import Dependencies
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
    self.build.number = { 42 }
    self.mainQueue = .immediate
    self.fileClient.save = { @Sendable _, _ in }
    self.storeKit.fetchProducts = { _ in
      .init(invalidProductIdentifiers: [], products: [])
    }
    self.storeKit.observer = { .finished }
    self.userSettings = .mock()
  }
}

@MainActor
class SettingsFeatureTests: XCTestCase {
  func testUserSettingsBackwardsDecodability() {
    XCTAssertNoDifference(
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
    XCTAssertNoDifference(
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

  // TODO: Fix once we have the TestStore binding test helper
//  func testEnableNotifications_NotDetermined_GrantAuthorization() async {
//    let didRegisterForRemoteNotifications = ActorIsolated(false)
//
//    let store = TestStore(
//      initialState: Settings.State()
//    ) {
//      Settings()
//    } withDependencies: {
//      $0.setUpDefaults()
//      $0.applicationClient.alternateIconName = { nil }
//      $0.fileClient.save = { @Sendable _, _ in }
//      $0.mainQueue = .immediate
//      $0.serverConfig.config = { .init() }
//      $0.userDefaults.boolForKey = { _ in false }
//      $0.userNotifications.getNotificationSettings = {
//        .init(authorizationStatus: .notDetermined)
//      }
//      $0.userNotifications.requestAuthorization = { _ in true }
//      $0.remoteNotifications.register = {
//        await didRegisterForRemoteNotifications.setValue(true)
//      }
//    }
//
//    let task = await store.send(.task) {
//      $0.buildNumber = 42
//      $0.developer.currentBaseUrl = .localhost
//      $0.fullGamePurchasedAt = .mock
//    }
//
//    await store.receive(
//      .userNotificationSettingsResponse(.init(authorizationStatus: .notDetermined))
//    ) {
//      $0.userNotificationSettings = .init(authorizationStatus: .notDetermined)
//    }
//
//    await store.send(.set(\.$enableNotifications, true)) {
//      $0.enableNotifications = true
//    }
//
//    await store.receive(.userNotificationAuthorizationResponse(.success(true)))
//
//    await didRegisterForRemoteNotifications.withValue { XCTAssert($0) }
//
//    await task.cancel()
//  }
//
//  func testEnableNotifications_NotDetermined_DenyAuthorization() async {
//    let store = TestStore(
//      initialState: Settings.State()
//    ) {
//      Settings()
//    } withDependencies: {
//      $0.setUpDefaults()
//      $0.applicationClient.alternateIconName = { nil }
//      $0.fileClient.save = { @Sendable _, _ in }
//      $0.mainQueue = .immediate
//      $0.serverConfig.config = { .init() }
//      $0.userDefaults.boolForKey = { _ in false }
//      $0.userNotifications.getNotificationSettings = {
//        .init(authorizationStatus: .notDetermined)
//      }
//      $0.userNotifications.requestAuthorization = { _ in false }
//    }
//
//    let task = await store.send(.task) {
//      $0.buildNumber = 42
//      $0.developer.currentBaseUrl = .localhost
//      $0.fullGamePurchasedAt = .mock
//    }
//
//    await store.receive(
//      .userNotificationSettingsResponse(.init(authorizationStatus: .notDetermined))
//    ) {
//      $0.userNotificationSettings = .init(authorizationStatus: .notDetermined)
//    }
//
//    await store.send(.set(\.$enableNotifications, true)) {
//      $0.enableNotifications = true
//    }
//
//    await store.receive(.userNotificationAuthorizationResponse(.success(false))) {
//      $0.enableNotifications = false
//    }
//
//    await task.cancel()
//  }
//
//  func testNotifications_PreviouslyGranted() async {
//    let store = TestStore(
//      initialState: Settings.State()
//    ) {
//      Settings()
//    } withDependencies: {
//      $0.setUpDefaults()
//      $0.applicationClient.alternateIconName = { nil }
//      $0.fileClient.save = { @Sendable _, _ in }
//      $0.mainQueue = .immediate
//      $0.serverConfig.config = { .init() }
//      $0.userDefaults.boolForKey = { _ in false }
//      $0.userNotifications.getNotificationSettings = {
//        .init(authorizationStatus: .authorized)
//      }
//    }
//
//    let task = await store.send(.task) {
//      $0.buildNumber = 42
//      $0.developer.currentBaseUrl = .localhost
//      $0.fullGamePurchasedAt = .mock
//    }
//
//    await store.receive(.userNotificationSettingsResponse(.init(authorizationStatus: .authorized)))
//    {
//      $0.enableNotifications = true
//      $0.userNotificationSettings = .init(authorizationStatus: .authorized)
//    }
//
//    await store.send(.set(\.$enableNotifications, false)) {
//      $0.enableNotifications = false
//    }
//
//    await task.cancel()
//  }
//
//  func testNotifications_PreviouslyDenied() async {
//    let openedUrl = ActorIsolated<URL?>(nil)
//    let store = TestStore(
//      initialState: Settings.State()
//    ) {
//      Settings()
//    } withDependencies: {
//      $0.setUpDefaults()
//      $0.applicationClient.alternateIconName = { nil }
//      $0.applicationClient.openSettingsURLString = {
//        "settings:isowords//isowords/settings"
//      }
//      $0.applicationClient.open = { url, _ in
//        await openedUrl.setValue(url)
//        return true
//      }
//      $0.fileClient.save = { @Sendable _, _ in }
//      $0.mainQueue = .immediate
//      $0.serverConfig.config = { .init() }
//      $0.userDefaults.boolForKey = { _ in false }
//      $0.userNotifications.getNotificationSettings = {
//        .init(authorizationStatus: .denied)
//      }
//    }
//
//    let task = await store.send(.task) {
//      $0.buildNumber = 42
//      $0.developer.currentBaseUrl = .localhost
//      $0.fullGamePurchasedAt = .mock
//    }
//
//    await store.receive(.userNotificationSettingsResponse(.init(authorizationStatus: .denied))) {
//      $0.userNotificationSettings = .init(authorizationStatus: .denied)
//    }
//
//    await store.send(.set(\.$enableNotifications, true)) {
//      $0.alert = .userNotificationAuthorizationDenied
//    }
//
//    await store.send(.alert(.presented(.openSettingButtonTapped))) {
//      $0.alert = nil
//    }
//
//    await openedUrl.withValue {
//      XCTAssertNoDifference($0, URL(string: "settings:isowords//isowords/settings")!)
//    }
//
//    await task.cancel()
//  }
//
//  func testNotifications_RemoteSettingsUpdates() async {
//    var userSettings = UserSettings(sendDailyChallengeReminder: false)
//    let didUpdate = LockIsolated(false)
//    let updatedBlobWithPurchase = update(CurrentPlayerEnvelope.blobWithPurchase) {
//      $0.player.sendDailyChallengeReminder = false
//    }
//
//    await withMainSerialExecutor {
//      let store = TestStore(
//        initialState: Settings.State()
//      ) {
//        Settings()
//      } withDependencies: {
//        $0.setUpDefaults()
//        $0.apiClient.refreshCurrentPlayer = {
//          didUpdate.value ? updatedBlobWithPurchase : .blobWithPurchase
//        }
//        $0.apiClient.override(
//          route: .push(
//            .updateSetting(.init(notificationType: .dailyChallengeEndsSoon, sendNotifications: false))
//          ),
//          withResponse: {
//            didUpdate.withValue { $0 = true }
//            return try await OK([:] as [String: Any])
//          }
//        )
//        $0.applicationClient.alternateIconName = { nil }
//        $0.fileClient.save = { @Sendable _, _ in }
//        $0.mainQueue = .immediate
//        $0.serverConfig.config = { .init() }
//        $0.userDefaults.boolForKey = { _ in false }
//        $0.userNotifications.getNotificationSettings = {
//          .init(authorizationStatus: .authorized)
//        }
//        $0.userSettings = .mock(initialUserSettings: userSettings)
//      }
//
//      let task = await store.send(.task) {
//        $0.buildNumber = 42
//        $0.developer.currentBaseUrl = .localhost
//        $0.fullGamePurchasedAt = .mock
//        $0.userSettings.sendDailyChallengeReminder = true
//      }
//
//      await store.receive(
//        .userNotificationSettingsResponse(.init(authorizationStatus: .authorized))
//      ) {
//        $0.enableNotifications = true
//        $0.userNotificationSettings = .init(authorizationStatus: .authorized)
//      }
//
//      userSettings.sendDailyChallengeReminder = false
//      await store.send(.set(\.$userSettings, userSettings)) {
//        $0.userSettings.sendDailyChallengeReminder = false
//      }
//      await store.receive(.currentPlayerRefreshed(.success(updatedBlobWithPurchase)))
//
//      await task.cancel()
//    }
//  }

  // MARK: - Sounds

  func testSetMusicVolume() async {
    let setMusicVolume = ActorIsolated<Float?>(nil)
    let store = TestStore(
      initialState: Settings.State()
    ) {
      Settings()
    } withDependencies: {
      $0.setUpDefaults()
      $0.audioPlayer.setGlobalVolumeForMusic = { await setMusicVolume.setValue($0) }
    }

    var userSettings = store.state.userSettings
    userSettings.musicVolume = 0.5
    await store.send(.set(\.$userSettings, userSettings)) {
      $0.userSettings.musicVolume = 0.5
    }

    await setMusicVolume.withValue { XCTAssertNoDifference($0, 0.5) }
  }

  func testSetSoundEffectsVolume() async {
    let setSoundEffectsVolume = ActorIsolated<Float?>(nil)
    let store = TestStore(
      initialState: Settings.State()
    ) {
      Settings()
    } withDependencies: {
      $0.setUpDefaults()
      $0.audioPlayer.setGlobalVolumeForSoundEffects = {
        await setSoundEffectsVolume.setValue($0)
      }
    }

    var userSettings = store.state.userSettings
    userSettings.soundEffectsVolume = 0.5
    await store.send(.set(\.$userSettings, userSettings)) {
      $0.userSettings.soundEffectsVolume = 0.5
    }

    await setSoundEffectsVolume.withValue { XCTAssertNoDifference($0, 0.5) }
  }

  // MARK: - Appearance

  func testSetColorScheme() async {
    let overriddenUserInterfaceStyle = ActorIsolated<UIUserInterfaceStyle?>(nil)
    let store = TestStore(
      initialState: Settings.State()
    ) {
      Settings()
    } withDependencies: {
      $0.setUpDefaults()
      $0.applicationClient.setUserInterfaceStyle = {
        await overriddenUserInterfaceStyle.setValue($0)
      }
    }

    var userSettings = store.state.userSettings
    userSettings.colorScheme = .light
    await store.send(.set(\.$userSettings, userSettings)) {
      $0.userSettings.colorScheme = .light
    }
    await overriddenUserInterfaceStyle.withValue { XCTAssertNoDifference($0, .light) }

    userSettings.colorScheme = .system
    await store.send(.set(\.$userSettings, userSettings)) {
      $0.userSettings.colorScheme = .system
    }
    await overriddenUserInterfaceStyle.withValue { XCTAssertNoDifference($0, .unspecified) }
  }

  func testSetAppIcon() async {
    let overriddenIconName = ActorIsolated<String?>(nil)
    let store = TestStore(
      initialState: Settings.State()
    ) {
      Settings()
    } withDependencies: {
      $0.setUpDefaults()
      $0.applicationClient.setAlternateIconName = {
        await overriddenIconName.setValue($0)
      }
    }

    var userSettings = store.state.userSettings
    userSettings.appIcon = .icon2
    await store.send(.set(\.$userSettings, userSettings)) {
      $0.userSettings.appIcon = .icon2
    }
    await overriddenIconName.withValue { XCTAssertNoDifference($0, "icon-2") }
  }

  func testUnsetAppIcon() async {
    let overriddenIconName = ActorIsolated<String?>(nil)
    let store = TestStore(
      initialState: Settings.State()
    ) {
      Settings()
    } withDependencies: {
      $0.setUpDefaults()
      $0.applicationClient.alternateIconName = { "icon-2" }
      $0.applicationClient.setAlternateIconName = {
        await overriddenIconName.setValue($0)
      }
      $0.mainQueue = .immediate
      $0.serverConfig.config = { .init() }
      $0.userDefaults.boolForKey = { _ in false }
      $0.userNotifications.getNotificationSettings = {
        (try? await Task.never()) ?? .init(authorizationStatus: .notDetermined)
      }
    }

    let task = await store.send(.task) {
      $0.buildNumber = 42
      $0.developer.currentBaseUrl = .localhost
      $0.fullGamePurchasedAt = .mock
      $0.userSettings.appIcon = .icon2
    }

    var userSettings = store.state.userSettings
    userSettings.appIcon = nil
    await store.send(.set(\.$userSettings, userSettings)) {
      $0.userSettings.appIcon = nil
    }
    await overriddenIconName.withValue { XCTAssertNil($0) }

    await task.cancel()
  }

  // MARK: - Developer

  func testSetApiBaseUrl() async {
    let setBaseUrl = ActorIsolated<URL?>(nil)
    let didLogout = ActorIsolated(false)
    let store = TestStore(
      initialState: Settings.State()
    ) {
      Settings()
    } withDependencies: {
      $0.setUpDefaults()
      $0.apiClient.logout = { await didLogout.setValue(true) }
      $0.apiClient.setBaseUrl = { await setBaseUrl.setValue($0) }
    }

    var developer = store.state.developer
    developer.currentBaseUrl = .localhost
    await store.send(.set(\.$developer, developer)) {
      $0.developer.currentBaseUrl = .localhost
    }
    await setBaseUrl.withValue { XCTAssertNoDifference($0, URL(string: "http://localhost:9876")!) }
    await didLogout.withValue { XCTAssert($0) }
  }

  func testToggleEnableGyroMotion() async {
    let store = TestStore(
      initialState: Settings.State()
    ) {
      Settings()
    } withDependencies: {
      $0.setUpDefaults()
      $0.userSettings = .mock(initialUserSettings: UserSettings(enableGyroMotion: true))
    }

    var userSettings = store.state.userSettings
    userSettings.enableGyroMotion = false
    await store.send(.set(\.$userSettings, userSettings)) {
      $0.userSettings.enableGyroMotion = false
    }
    userSettings.enableGyroMotion = true
    await store.send(.set(\.$userSettings, userSettings)) {
      $0.userSettings.enableGyroMotion = true
    }
  }

  func testToggleEnableHaptics() async {
    let store = TestStore(
      initialState: Settings.State()
    ) {
      Settings()
    } withDependencies: {
      $0.setUpDefaults()
      $0.userSettings = .mock(initialUserSettings: UserSettings(enableHaptics: true))
    }


    var userSettings = store.state.userSettings
    userSettings.enableHaptics = false
    await store.send(.set(\.$userSettings, userSettings)) {
      $0.userSettings.enableHaptics = false
    }
    userSettings.enableHaptics = true
    await store.send(.set(\.$userSettings, userSettings)) {
      $0.userSettings.enableHaptics = true
    }
  }
}
