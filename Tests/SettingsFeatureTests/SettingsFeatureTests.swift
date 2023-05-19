import ApiClient
import Combine
import ComposableArchitecture
import ComposableUserNotifications
@_spi(Concurrency) import Dependencies
import SharedModels
import TestHelpers
import UserDefaultsClient
import UserNotifications
import XCTest

@testable import SettingsFeature

fileprivate extension DependencyValues {
  mutating func setUpDefaults() {
    self.apiClient.baseUrl = { URL(string: "http://localhost:9876")! }
    self.apiClient.currentPlayer = { .some(.init(appleReceipt: .mock, player: .blob)) }
    self.build.number = { 42 }
    self.mainQueue = .immediate
    self.fileClient.save = { @Sendable _, _ in }
    self.storeKit.fetchProducts = { _ in
      .init(invalidProductIdentifiers: [], products: [])
    }
    self.storeKit.observer = { .finished }
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

  func testEnableNotifications_NotDetermined_GrantAuthorization() async {
    let didRegisterForRemoteNotifications = ActorIsolated(false)

    let store = TestStore(
      initialState: Settings.State(),
      reducer: Settings()
    )

    store.dependencies.setUpDefaults()
    store.dependencies.applicationClient.alternateIconName = { nil }
    store.dependencies.fileClient.save = { @Sendable _, _ in }
    store.dependencies.mainQueue = .immediate
    store.dependencies.serverConfig.config = { .init() }
    store.dependencies.userDefaults.boolForKey = { _ in false }
    store.dependencies.userNotifications.getNotificationSettings = {
      .init(authorizationStatus: .notDetermined)
    }
    store.dependencies.userNotifications.requestAuthorization = { _ in true }
    store.dependencies.remoteNotifications.register = {
      await didRegisterForRemoteNotifications.setValue(true)
    }

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
    let store = TestStore(
      initialState: Settings.State(),
      reducer: Settings()
    )

    store.dependencies.setUpDefaults()
    store.dependencies.applicationClient.alternateIconName = { nil }
    store.dependencies.fileClient.save = { @Sendable _, _ in }
    store.dependencies.mainQueue = .immediate
    store.dependencies.serverConfig.config = { .init() }
    store.dependencies.userDefaults.boolForKey = { _ in false }
    store.dependencies.userNotifications.getNotificationSettings = {
      .init(authorizationStatus: .notDetermined)
    }
    store.dependencies.userNotifications.requestAuthorization = { _ in false }

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
    let store = TestStore(
      initialState: Settings.State(),
      reducer: Settings()
    )

    store.dependencies.setUpDefaults()
    store.dependencies.applicationClient.alternateIconName = { nil }
    store.dependencies.fileClient.save = { @Sendable _, _ in }
    store.dependencies.mainQueue = .immediate
    store.dependencies.serverConfig.config = { .init() }
    store.dependencies.userDefaults.boolForKey = { _ in false }
    store.dependencies.userNotifications.getNotificationSettings = {
      .init(authorizationStatus: .authorized)
    }

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
    let store = TestStore(
      initialState: Settings.State(),
      reducer: Settings()
    )

    let openedUrl = ActorIsolated<URL?>(nil)
    store.dependencies.setUpDefaults()
    store.dependencies.applicationClient.alternateIconName = { nil }
    store.dependencies.applicationClient.openSettingsURLString = {
      "settings:isowords//isowords/settings"
    }
    store.dependencies.applicationClient.open = { url, _ in
      await openedUrl.setValue(url)
      return true
    }
    store.dependencies.fileClient.save = { @Sendable _, _ in }
    store.dependencies.mainQueue = .immediate
    store.dependencies.serverConfig.config = { .init() }
    store.dependencies.userDefaults.boolForKey = { _ in false }
    store.dependencies.userNotifications.getNotificationSettings = {
      .init(authorizationStatus: .denied)
    }

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
    await withMainSerialExecutor {
      let store = TestStore(
        initialState: Settings.State(sendDailyChallengeReminder: false),
        reducer: Settings()
      )

      let mainQueue = DispatchQueue.test
      store.dependencies.setUpDefaults()
      store.dependencies.apiClient.refreshCurrentPlayer = { .blobWithPurchase }
      store.dependencies.apiClient.override(
        route: .push(
          .updateSetting(.init(notificationType: .dailyChallengeReport, sendNotifications: true))
        ),
        withResponse: { try await OK([:] as [String: Any]) }
      )
      store.dependencies.applicationClient.alternateIconName = { nil }
      store.dependencies.fileClient.save = { @Sendable _, _ in }
      store.dependencies.mainQueue = mainQueue.eraseToAnyScheduler()
      store.dependencies.serverConfig.config = { .init() }
      store.dependencies.userDefaults.boolForKey = { _ in false }
      store.dependencies.userNotifications.getNotificationSettings = {
        .init(authorizationStatus: .authorized)
      }

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
  }

  // MARK: - Sounds

  func testSetMusicVolume() async {
    let store = TestStore(
      initialState: Settings.State(),
      reducer: Settings()
    )

    let setMusicVolume = ActorIsolated<Float?>(nil)
    store.dependencies.setUpDefaults()
    store.dependencies.audioPlayer.setGlobalVolumeForMusic = { await setMusicVolume.setValue($0) }

    await store.send(.set(\.$userSettings.musicVolume, 0.5)) {
      $0.userSettings.musicVolume = 0.5
    }

    await setMusicVolume.withValue { XCTAssertNoDifference($0, 0.5) }
  }

  func testSetSoundEffectsVolume() async {
    let store = TestStore(
      initialState: Settings.State(),
      reducer: Settings()
    )

    let setSoundEffectsVolume = ActorIsolated<Float?>(nil)
    store.dependencies.setUpDefaults()
    store.dependencies.audioPlayer.setGlobalVolumeForSoundEffects = {
      await setSoundEffectsVolume.setValue($0)
    }

    await store.send(.set(\.$userSettings.soundEffectsVolume, 0.5)) {
      $0.userSettings.soundEffectsVolume = 0.5
    }

    await setSoundEffectsVolume.withValue { XCTAssertNoDifference($0, 0.5) }
  }

  // MARK: - Appearance

  func testSetColorScheme() async {
    let store = TestStore(
      initialState: Settings.State(),
      reducer: Settings()
    )

    let overriddenUserInterfaceStyle = ActorIsolated<UIUserInterfaceStyle?>(nil)
    store.dependencies.setUpDefaults()
    store.dependencies.applicationClient.setUserInterfaceStyle = {
      await overriddenUserInterfaceStyle.setValue($0)
    }

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
    let store = TestStore(
      initialState: Settings.State(),
      reducer: Settings()
    )

    let overriddenIconName = ActorIsolated<String?>(nil)
    store.dependencies.setUpDefaults()
    store.dependencies.applicationClient.setAlternateIconName = {
      await overriddenIconName.setValue($0)
    }

    await store.send(.set(\.$userSettings.appIcon, .icon2)) {
      $0.userSettings.appIcon = .icon2
    }
    await overriddenIconName.withValue { XCTAssertNoDifference($0, "icon-2") }
  }

  func testUnsetAppIcon() async {
    let store = TestStore(
      initialState: Settings.State(),
      reducer: Settings()
    )

    let overriddenIconName = ActorIsolated<String?>(nil)
    store.dependencies.setUpDefaults()
    store.dependencies.applicationClient.alternateIconName = { "icon-2" }
    store.dependencies.applicationClient.setAlternateIconName = { await overriddenIconName.setValue($0) }
    store.dependencies.mainQueue = .immediate
    store.dependencies.serverConfig.config = { .init() }
    store.dependencies.userDefaults.boolForKey = { _ in false }
    store.dependencies.userNotifications.getNotificationSettings = {
      (try? await Task.never()) ?? .init(authorizationStatus: .notDetermined)
    }

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
    let store = TestStore(
      initialState: Settings.State(),
      reducer: Settings()
    )

    let setBaseUrl = ActorIsolated<URL?>(nil)
    let didLogout = ActorIsolated(false)

    store.dependencies.setUpDefaults()
    store.dependencies.apiClient.logout = { await didLogout.setValue(true) }
    store.dependencies.apiClient.setBaseUrl = { await setBaseUrl.setValue($0) }

    await store.send(.set(\.$developer.currentBaseUrl, .localhost)) {
      $0.developer.currentBaseUrl = .localhost
    }
    await setBaseUrl.withValue { XCTAssertNoDifference($0, URL(string: "http://localhost:9876")!) }
    await didLogout.withValue { XCTAssert($0) }
  }

  func testToggleEnableCubeShadow() async {
    let store = TestStore(
      initialState: Settings.State(enableCubeShadow: true),
      reducer: Settings()
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
      initialState: Settings.State(cubeShadowRadius: 5),
      reducer: Settings()
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
      initialState: Settings.State(showSceneStatistics: false),
      reducer: Settings()
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
      initialState: Settings.State(userSettings: .init(enableGyroMotion: true)),
      reducer: Settings()
    )

    store.dependencies.setUpDefaults()

    await store.send(.set(\.$userSettings.enableGyroMotion, false)) {
      $0.userSettings.enableGyroMotion = false
    }
    await store.send(.set(\.$userSettings.enableGyroMotion, true)) {
      $0.userSettings.enableGyroMotion = true
    }
  }

  func testToggleEnableHaptics() async {
    let store = TestStore(
      initialState: Settings.State(userSettings: .init(enableHaptics: true)),
      reducer: Settings()
    )

    store.dependencies.setUpDefaults()

    await store.send(.set(\.$userSettings.enableHaptics, false)) {
      $0.userSettings.enableHaptics = false
    }
    await store.send(.set(\.$userSettings.enableHaptics, true)) {
      $0.userSettings.enableHaptics = true
    }
  }
}
