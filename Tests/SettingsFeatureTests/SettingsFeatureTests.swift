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
    var environment = SettingsEnvironment.failing
    environment.apiClient.baseUrl = { URL(string: "http://localhost:9876")! }
    environment.apiClient.currentPlayer = { .some(.init(appleReceipt: .mock, player: .blob)) }
    environment.build.number = { 42 }
    environment.mainQueue = .immediate
    environment.backgroundQueue = .immediate
    environment.fileClient.saveAsync = { @Sendable _, _ in }
    environment.storeKit.fetchProducts = { _ in .none }
    environment.storeKit.observer = .run { _ in AnyCancellable {} }
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
    var didRegisterForRemoteNotifications = false

    var environment = self.defaultEnvironment
    environment.applicationClient.alternateIconName = { nil }
    environment.backgroundQueue = .immediate
    environment.fileClient.save = { _, _ in .none }
    environment.mainQueue = .immediate
    environment.serverConfig.config = { .init() }
    environment.userDefaults.boolForKey = { _ in false }
    environment.userNotifications.getNotificationSettings = .init(
      value: .init(authorizationStatus: .notDetermined)
    )
    environment.userNotifications.requestAuthorizationAsync = { _ in true }
    environment.remoteNotifications.registerAsync = { didRegisterForRemoteNotifications = true }

    let store = TestStore(
      initialState: SettingsState(),
      reducer: settingsReducer,
      environment: environment
    )

    await store.send(.onAppear) {
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

    XCTAssert(didRegisterForRemoteNotifications)

    await store.send(.onDismiss)
  }

  func testEnableNotifications_NotDetermined_DenyAuthorization() async {
    var environment = self.defaultEnvironment
    environment.applicationClient.alternateIconName = { nil }
    environment.backgroundQueue = .immediate
    environment.fileClient.save = { _, _ in .none }
    environment.mainQueue = .immediate
    environment.serverConfig.config = { .init() }
    environment.userDefaults.boolForKey = { _ in false }
    environment.userNotifications.getNotificationSettings = .init(
      value: .init(authorizationStatus: .notDetermined)
    )
    environment.userNotifications.requestAuthorizationAsync = { _ in false }

    let store = TestStore(
      initialState: SettingsState(),
      reducer: settingsReducer,
      environment: environment
    )

    await store.send(.onAppear) {
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

    await store.send(.onDismiss)
  }

  func testNotifications_PreviouslyGranted() async {
    var environment = self.defaultEnvironment
    environment.applicationClient.alternateIconName = { nil }
    environment.backgroundQueue = .immediate
    environment.fileClient.save = { _, _ in .none }
    environment.mainQueue = .immediate
    environment.remoteNotifications.register = { .none }
    environment.serverConfig.config = { .init() }
    environment.userDefaults.boolForKey = { _ in false }
    environment.userNotifications.getNotificationSettings = .init(
      value: .init(authorizationStatus: .authorized)
    )

    let store = TestStore(
      initialState: SettingsState(),
      reducer: settingsReducer,
      environment: environment
    )

    await store.send(.onAppear) {
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

    await store.send(.onDismiss)
  }

  func testNotifications_PreviouslyDenied() async {
    var openedUrl: URL!

    var environment = self.defaultEnvironment
    environment.applicationClient.alternateIconName = { nil }
    environment.applicationClient.openSettingsURLStringAsync = {
      "settings:isowords//isowords/settings"
    }
    environment.applicationClient.openAsync = { url, _ in
      openedUrl = url
      return true
    }
    environment.backgroundQueue = .immediate
    environment.fileClient.save = { _, _ in .none }
    environment.mainQueue = .immediate
    environment.serverConfig.config = { .init() }
    environment.userDefaults.boolForKey = { _ in false }
    environment.userNotifications.getNotificationSettings = .init(
      value: .init(authorizationStatus: .denied)
    )

    let store = TestStore(
      initialState: SettingsState(),
      reducer: settingsReducer,
      environment: environment
    )

    await store.send(.onAppear) {
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

    XCTAssertNoDifference(openedUrl, URL(string: "settings:isowords//isowords/settings")!)

    await store.send(.set(\.$alert, nil)) {
      $0.alert = nil
    }

    await store.send(.onDismiss)
  }

  func testNotifications_DebounceRemoteSettingsUpdates() async {
    let mainQueue = DispatchQueue.test

    var environment = self.defaultEnvironment
    environment.apiClient.refreshCurrentPlayer = { .init(value: .blobWithPurchase) }
    environment.apiClient.override(
      route: .push(
        .updateSetting(.init(notificationType: .dailyChallengeEndsSoon, sendNotifications: true))
      ),
      withResponse: .none
    )
    environment.apiClient.override(
      route: .push(
        .updateSetting(.init(notificationType: .dailyChallengeReport, sendNotifications: true))
      ),
      withResponse: .none
    )
    environment.applicationClient.alternateIconName = { nil }
    environment.backgroundQueue = .immediate
    environment.fileClient.save = { _, _ in .none }
    environment.mainQueue = mainQueue.eraseToAnyScheduler()
    environment.remoteNotifications.register = { .none }
    environment.serverConfig.config = { .init() }
    environment.userDefaults.boolForKey = { _ in false }
    environment.userNotifications.getNotificationSettings = .init(
      value: .init(authorizationStatus: .authorized)
    )

    let store = TestStore(
      initialState: SettingsState(sendDailyChallengeReminder: false),
      reducer: settingsReducer,
      environment: environment
    )

    await store.send(.onAppear) {
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

    await store.send(.onDismiss)
  }

  // MARK: - Sounds

  func testSetMusicVolume() async {
    var setMusicVolume: Float!

    var environment = self.defaultEnvironment
    environment.audioPlayer.setGlobalVolumeForMusicAsync = { setMusicVolume = $0 }

    let store = TestStore(
      initialState: SettingsState(),
      reducer: settingsReducer,
      environment: environment
    )

    await store.send(.set(\.$userSettings.musicVolume, 0.5)) {
      $0.userSettings.musicVolume = 0.5
    }

    XCTAssertNoDifference(setMusicVolume, 0.5)
  }

  func testSetSoundEffectsVolume() async {
    var setSoundEffectsVolume: Float!

    var environment = self.defaultEnvironment
    environment.audioPlayer.setGlobalVolumeForSoundEffectsAsync = { setSoundEffectsVolume = $0 }

    let store = TestStore(
      initialState: SettingsState(),
      reducer: settingsReducer,
      environment: environment
    )

    await store.send(.set(\.$userSettings.soundEffectsVolume, 0.5)) {
      $0.userSettings.soundEffectsVolume = 0.5
    }

    XCTAssertNoDifference(setSoundEffectsVolume, 0.5)
  }

  // MARK: - Appearance

  func testSetColorScheme() async {
    var overriddenUserInterfaceStyle: UIUserInterfaceStyle!

    var environment = self.defaultEnvironment
    environment.setUserInterfaceStyleAsync = { overriddenUserInterfaceStyle = $0 }

    let store = TestStore(
      initialState: SettingsState(),
      reducer: settingsReducer,
      environment: environment
    )

    await store.send(.set(\.$userSettings.colorScheme, .light)) {
      $0.userSettings.colorScheme = .light
    }
    XCTAssertNoDifference(overriddenUserInterfaceStyle, .light)

    await store.send(.set(\.$userSettings.colorScheme, .system)) {
      $0.userSettings.colorScheme = .system
    }
    XCTAssertNoDifference(overriddenUserInterfaceStyle, .unspecified)
  }

  func testSetAppIcon() async {
    var overriddenIconName: String!

    var environment = self.defaultEnvironment
    environment.applicationClient.setAlternateIconNameAsync = { overriddenIconName = $0 }

    let store = TestStore(
      initialState: SettingsState(),
      reducer: settingsReducer,
      environment: environment
    )

    await store.send(.set(\.$userSettings.appIcon, .icon2)) {
      $0.userSettings.appIcon = .icon2
    }
    XCTAssertNoDifference(overriddenIconName, "icon-2")
  }

  func testUnsetAppIcon() async {
    var overriddenIconName: String?

    var environment = self.defaultEnvironment
    environment.applicationClient.alternateIconName = { "icon-2" }
    environment.applicationClient.setAlternateIconNameAsync = { overriddenIconName = $0 }
    environment.backgroundQueue = .immediate
    environment.mainQueue = .immediate
    environment.serverConfig.config = { .init() }
    environment.userDefaults.boolForKey = { _ in false }
    environment.userNotifications.getNotificationSettings = .none

    let store = TestStore(
      initialState: SettingsState(),
      reducer: settingsReducer,
      environment: environment
    )

    await store.send(.onAppear) {
      $0.buildNumber = 42
      $0.developer.currentBaseUrl = .localhost
      $0.fullGamePurchasedAt = .mock
      $0.userSettings.appIcon = .icon2
    }

    await store.send(.set(\.$userSettings.appIcon, nil)) {
      $0.userSettings.appIcon = nil
    }
    XCTAssertNoDifference(overriddenIconName, nil)

    await store.send(.onDismiss)
  }

  // MARK: - Developer

  func testSetApiBaseUrl() async {
    var setBaseUrl: URL!
    var didLogout = false

    var environment = SettingsEnvironment.failing
    environment.apiClient.logoutAsync = { didLogout = true }
    environment.apiClient.setBaseUrlAsync = { setBaseUrl = $0 }

    let store = TestStore(
      initialState: SettingsState(),
      reducer: settingsReducer,
      environment: environment
    )

    await store.send(.set(\.$developer.currentBaseUrl, .localhost)) {
      $0.developer.currentBaseUrl = .localhost
    }
    XCTAssertNoDifference(setBaseUrl, URL(string: "http://localhost:9876")!)
    XCTAssertNoDifference(didLogout, true)
  }

  func testToggleEnableCubeShadow() async {
    let store = TestStore(
      initialState: SettingsState(enableCubeShadow: true),
      reducer: settingsReducer,
      environment: .failing
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
      environment: .failing
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
      environment: .failing
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
