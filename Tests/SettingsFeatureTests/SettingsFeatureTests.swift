import ApiClient
import Combine
import ComposableArchitecture
import ComposableUserNotifications
import SharedModels
import TestHelpers
import UserNotifications
import XCTest

@testable import SettingsFeature

@MainActor
class SettingsFeatureTests: XCTestCase {
  var defaultEnvironment: SettingsEnvironment {
    var environment = SettingsEnvironment.unimplemented
    environment.apiClient.baseUrl = { URL(string: "http://localhost:9876")! }
    environment.apiClient.currentPlayer = { .some(.init(appleReceipt: .mock, player: .blob)) }
    environment.build.number = { 42 }
    environment.mainQueue = .immediate
    environment.backgroundQueue = .immediate
    environment.fileClient.save = { @Sendable _, _ in }
    environment.storeKit.fetchProducts = { _ in
      .init(invalidProductIdentifiers: [], products: [])
    }
    environment.storeKit.observer =  { .finished }
    return environment
  }

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

  func testEnableNotifications_NotDetermined_GrantAuthorization() async {
    let didRegisterForRemoteNotifications = ActorIsolated(false)

    var environment = self.defaultEnvironment
    environment.applicationClient.alternateIconName = { nil }
    environment.backgroundQueue = .immediate
    environment.fileClient.save = { @Sendable _, _ in }
    environment.mainQueue = .immediate
    environment.serverConfig.config = { .init() }
    environment.userDefaults.boolForKey = { _ in false }
    environment.userNotifications.getNotificationSettings = {
      .init(authorizationStatus: .notDetermined)
    }
    environment.userNotifications.requestAuthorization = { _ in true }
    environment.remoteNotifications.register = {
      await didRegisterForRemoteNotifications.setValue(true)
    }

    let store = TestStore(
      initialState: SettingsState(),
      reducer: settingsReducer,
      environment: environment
    )

    let task = await store.send(.task) {
      $0.buildNumber = 42
      $0.developer.currentBaseUrl = .localhost
      $0.fullGamePurchasedAt = .mock
    }

    await store.receive(.userNotificationSettingsResponse(.init(authorizationStatus: .notDetermined))) {
      $0.userNotificationSettings = .init(authorizationStatus: .notDetermined)
    }

    await store.send(.set(\.$enableNotifications, true)) {
      $0.enableNotifications = true
    }

    await store.receive(.userNotificationAuthorizationResponse(.success(true)))

    await didRegisterForRemoteNotifications.withValue { XCTAssert($0) }

    await task.cancel()
  }

  func testEnableNotifications_NotDetermined_DenyAuthorization() async {
    var environment = self.defaultEnvironment
    environment.applicationClient.alternateIconName = { nil }
    environment.backgroundQueue = .immediate
    environment.fileClient.save = { @Sendable _, _ in }
    environment.mainQueue = .immediate
    environment.serverConfig.config = { .init() }
    environment.userDefaults.boolForKey = { _ in false }
    environment.userNotifications.getNotificationSettings = {
      .init(authorizationStatus: .notDetermined)
    }
    environment.userNotifications.requestAuthorization = { _ in false }

    let store = TestStore(
      initialState: SettingsState(),
      reducer: settingsReducer,
      environment: environment
    )

    let task = await store.send(.task) {
      $0.buildNumber = 42
      $0.developer.currentBaseUrl = .localhost
      $0.fullGamePurchasedAt = .mock
    }

    await store.receive(.userNotificationSettingsResponse(.init(authorizationStatus: .notDetermined))) {
      $0.userNotificationSettings = .init(authorizationStatus: .notDetermined)
    }

    await store.send(.set(\.$enableNotifications, true)) {
      $0.enableNotifications = true
    }

    await store.receive(.userNotificationAuthorizationResponse(.success(false))) {
      $0.enableNotifications = false
    }

    await task.cancel()
  }

  func testNotifications_PreviouslyGranted() async {
    var environment = self.defaultEnvironment
    environment.applicationClient.alternateIconName = { nil }
    environment.backgroundQueue = .immediate
    environment.fileClient.save = { @Sendable _, _ in }
    environment.mainQueue = .immediate
    environment.serverConfig.config = { .init() }
    environment.userDefaults.boolForKey = { _ in false }
    environment.userNotifications.getNotificationSettings = {
      .init(authorizationStatus: .authorized)
    }

    let store = TestStore(
      initialState: SettingsState(),
      reducer: settingsReducer,
      environment: environment
    )

    let task = await store.send(.task) {
      $0.buildNumber = 42
      $0.developer.currentBaseUrl = .localhost
      $0.fullGamePurchasedAt = .mock
    }

    await store.receive(.userNotificationSettingsResponse(.init(authorizationStatus: .authorized))) {
      $0.enableNotifications = true
      $0.userNotificationSettings = .init(authorizationStatus: .authorized)
    }

    await store.send(.set(\.$enableNotifications, false)) {
      $0.enableNotifications = false
    }

    await task.cancel()
  }

  func testNotifications_PreviouslyDenied() async {
    let openedUrl = ActorIsolated<URL?>(nil)

    var environment = self.defaultEnvironment
    environment.applicationClient.alternateIconName = { nil }
    environment.applicationClient.openSettingsURLString = {
      "settings:isowords//isowords/settings"
    }
    environment.applicationClient.open = { url, _ in
      await openedUrl.setValue(url)
      return true
    }
    environment.backgroundQueue = .immediate
    environment.fileClient.save = { @Sendable _, _ in }
    environment.mainQueue = .immediate
    environment.serverConfig.config = { .init() }
    environment.userDefaults.boolForKey = { _ in false }
    environment.userNotifications.getNotificationSettings = {
      .init(authorizationStatus: .denied)
    }

    let store = TestStore(
      initialState: SettingsState(),
      reducer: settingsReducer,
      environment: environment
    )

    let task = await store.send(.task) {
      $0.buildNumber = 42
      $0.developer.currentBaseUrl = .localhost
      $0.fullGamePurchasedAt = .mock
    }

    await store.receive(.userNotificationSettingsResponse(.init(authorizationStatus: .denied))) {
      $0.userNotificationSettings = .init(authorizationStatus: .denied)
    }

    await store.send(.set(\.$enableNotifications, true)) {
      $0.alert = .userNotificationAuthorizationDenied
    }

    await store.send(.openSettingButtonTapped)

    await openedUrl.withValue {
      XCTAssertNoDifference($0, URL(string: "settings:isowords//isowords/settings")!)
    }

    await store.send(.set(\.$alert, nil)) {
      $0.alert = nil
    }

    await task.cancel()
  }

  func testNotifications_DebounceRemoteSettingsUpdates() async {
    let mainQueue = DispatchQueue.test

    var environment = self.defaultEnvironment
    environment.apiClient.refreshCurrentPlayer = { .blobWithPurchase }
    environment.apiClient.override(
      route: .push(
        .updateSetting(.init(notificationType: .dailyChallengeReport, sendNotifications: true))
      ),
      withResponse: { try await OK([:]) }
    )
    environment.applicationClient.alternateIconName = { nil }
    environment.backgroundQueue = .immediate
    environment.fileClient.save = { @Sendable _, _ in }
    environment.mainQueue = mainQueue.eraseToAnyScheduler()
    environment.serverConfig.config = { .init() }
    environment.userDefaults.boolForKey = { _ in false }
    environment.userNotifications.getNotificationSettings = {
      .init(authorizationStatus: .authorized)
    }

    let store = TestStore(
      initialState: SettingsState(sendDailyChallengeReminder: false),
      reducer: settingsReducer,
      environment: environment
    )

    let task = await store.send(.task) {
      $0.buildNumber = 42
      $0.developer.currentBaseUrl = .localhost
      $0.fullGamePurchasedAt = .mock
    }

    await mainQueue.advance()

    await store.receive(.userNotificationSettingsResponse(.init(authorizationStatus: .authorized))) {
      $0.enableNotifications = true
      $0.userNotificationSettings = .init(authorizationStatus: .authorized)
    }

    await store.send(.set(\.$sendDailyChallengeReminder, true)) {
      $0.sendDailyChallengeReminder = true
    }
    await mainQueue.advance(by: 0.5)

    await store.send(.set(\.$sendDailyChallengeSummary, true))
    await mainQueue.advance(by: 0.5)
    await mainQueue.advance(by: 0.5)

    await store.receive(.currentPlayerRefreshed(.success(.blobWithPurchase)))

    await task.cancel()
  }

  // MARK: - Sounds

  func testSetMusicVolume() async {
    let setMusicVolume = ActorIsolated<Float?>(nil)

    var environment = self.defaultEnvironment
    environment.audioPlayer.setGlobalVolumeForMusic = { await setMusicVolume.setValue($0) }

    let store = TestStore(
      initialState: SettingsState(),
      reducer: settingsReducer,
      environment: environment
    )

    await store.send(.set(\.$userSettings.musicVolume, 0.5)) {
      $0.userSettings.musicVolume = 0.5
    }

    await setMusicVolume.withValue { XCTAssertNoDifference($0, 0.5) }
  }

  func testSetSoundEffectsVolume() async {
    let setSoundEffectsVolume = ActorIsolated<Float?>(nil)

    var environment = self.defaultEnvironment
    environment.audioPlayer.setGlobalVolumeForSoundEffects = {
      await setSoundEffectsVolume.setValue($0)
    }

    let store = TestStore(
      initialState: SettingsState(),
      reducer: settingsReducer,
      environment: environment
    )

    await store.send(.set(\.$userSettings.soundEffectsVolume, 0.5)) {
      $0.userSettings.soundEffectsVolume = 0.5
    }

    await setSoundEffectsVolume.withValue { XCTAssertNoDifference($0, 0.5) }
  }

  // MARK: - Appearance

  func testSetColorScheme() async {
    let overriddenUserInterfaceStyle = ActorIsolated<UIUserInterfaceStyle?>(nil)

    var environment = self.defaultEnvironment
    environment.setUserInterfaceStyle = { await overriddenUserInterfaceStyle.setValue($0) }

    let store = TestStore(
      initialState: SettingsState(),
      reducer: settingsReducer,
      environment: environment
    )

    await store.send(.set(\.$userSettings.colorScheme, .light)) {
      $0.userSettings.colorScheme = .light
    }
    await overriddenUserInterfaceStyle.withValue { XCTAssertNoDifference($0, .light) }

    await store.send(.set(\.$userSettings.colorScheme, .system)) {
      $0.userSettings.colorScheme = .system
    }
    await overriddenUserInterfaceStyle.withValue { XCTAssertNoDifference($0, .unspecified) }
  }

  func testSetAppIcon() async {
    let overriddenIconName = ActorIsolated<String?>(nil)

    var environment = self.defaultEnvironment
    environment.applicationClient.setAlternateIconName = { await overriddenIconName.setValue($0) }

    let store = TestStore(
      initialState: SettingsState(),
      reducer: settingsReducer,
      environment: environment
    )

    await store.send(.set(\.$userSettings.appIcon, .icon2)) {
      $0.userSettings.appIcon = .icon2
    }
    await overriddenIconName.withValue { XCTAssertNoDifference($0, "icon-2") }
  }

  func testUnsetAppIcon() async {
    let overriddenIconName = ActorIsolated<String?>(nil)

    var environment = self.defaultEnvironment
    environment.applicationClient.alternateIconName = { "icon-2" }
    environment.applicationClient.setAlternateIconName = { await overriddenIconName.setValue($0) }
    environment.backgroundQueue = .immediate
    environment.mainQueue = .immediate
    environment.serverConfig.config = { .init() }
    environment.userDefaults.boolForKey = { _ in false }
    environment.userNotifications.getNotificationSettings = {
      (try? await Task.never()) ?? .init(authorizationStatus: .notDetermined)
    }

    let store = TestStore(
      initialState: SettingsState(),
      reducer: settingsReducer,
      environment: environment
    )

    let task = await store.send(.task) {
      $0.buildNumber = 42
      $0.developer.currentBaseUrl = .localhost
      $0.fullGamePurchasedAt = .mock
      $0.userSettings.appIcon = .icon2
    }

    await store.send(.set(\.$userSettings.appIcon, nil)) {
      $0.userSettings.appIcon = nil
    }
    await overriddenIconName.withValue { XCTAssertNil($0) }

    await task.cancel()
  }

  // MARK: - Developer

  func testSetApiBaseUrl() async {
    let setBaseUrl = ActorIsolated<URL?>(nil)
    let didLogout = ActorIsolated(false)

    var environment = SettingsEnvironment.unimplemented
    environment.apiClient.logout = { await didLogout.setValue(true) }
    environment.apiClient.setBaseUrl = { await setBaseUrl.setValue($0) }

    let store = TestStore(
      initialState: SettingsState(),
      reducer: settingsReducer,
      environment: environment
    )

    await store.send(.set(\.$developer.currentBaseUrl, .localhost)) {
      $0.developer.currentBaseUrl = .localhost
    }
    await setBaseUrl.withValue { XCTAssertNoDifference($0, URL(string: "http://localhost:9876")!) }
    await didLogout.withValue { XCTAssert($0) }
  }

  func testToggleEnableCubeShadow() async {
    let store = TestStore(
      initialState: SettingsState(enableCubeShadow: true),
      reducer: settingsReducer,
      environment: .unimplemented
    )

    await store.send(.set(\.$enableCubeShadow, false)) {
      $0.enableCubeShadow = false
    }
    await store.send(.set(\.$enableCubeShadow, true)) {
      $0.enableCubeShadow = true
    }
  }

  func testSetShadowRadius() async {
    let store = TestStore(
      initialState: SettingsState(cubeShadowRadius: 5),
      reducer: settingsReducer,
      environment: .unimplemented
    )

    await store.send(.set(\.$cubeShadowRadius, 20)) {
      $0.cubeShadowRadius = 20
    }
    await store.send(.set(\.$cubeShadowRadius, 1.5)) {
      $0.cubeShadowRadius = 1.5
    }
  }

  func testToggleShowSceneStatistics() async {
    let store = TestStore(
      initialState: SettingsState(showSceneStatistics: false),
      reducer: settingsReducer,
      environment: .unimplemented
    )

    await store.send(.set(\.$showSceneStatistics, true)) {
      $0.showSceneStatistics = true
    }
    await store.send(.set(\.$showSceneStatistics, false)) {
      $0.showSceneStatistics = false
    }
  }

  func testToggleEnableGyroMotion() async {
    let store = TestStore(
      initialState: SettingsState(userSettings: .init(enableGyroMotion: true)),
      reducer: settingsReducer,
      environment: self.defaultEnvironment
    )

    await store.send(.set(\.$userSettings.enableGyroMotion, false)) {
      $0.userSettings.enableGyroMotion = false
    }
    await store.send(.set(\.$userSettings.enableGyroMotion, true)) {
      $0.userSettings.enableGyroMotion = true
    }
  }

  func testToggleEnableHaptics() async {
    let store = TestStore(
      initialState: SettingsState(userSettings: .init(enableHaptics: true)),
      reducer: settingsReducer,
      environment: self.defaultEnvironment
    )

    await store.send(.set(\.$userSettings.enableHaptics, false)) {
      $0.userSettings.enableHaptics = false
    }
    await store.send(.set(\.$userSettings.enableHaptics, true)) {
      $0.userSettings.enableHaptics = true
    }
  }
}
