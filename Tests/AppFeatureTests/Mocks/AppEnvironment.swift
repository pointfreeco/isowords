import AppFeature
import ClientModels
import ComposableArchitecture
import FileClient
import Foundation
import Overture
import SettingsFeature
import UserDefaultsClient

extension AppEnvironment {
  static let didFinishLaunching = update(failing) {
    $0.audioPlayer.load = { _ in }
    $0.backgroundQueue = .immediate
    $0.database.migrate = {}
    $0.dictionary.load = { _ in false }
    $0.fileClient.load = { @Sendable _ in try await Task.never() }
    $0.gameCenter.localPlayer.authenticate = {}
    $0.gameCenter.localPlayer.listener = { .finished }
    $0.mainQueue = .immediate
    $0.mainRunLoop = .immediate
    $0.serverConfig.refresh = { .init() }
    $0.storeKit.observer = { .finished }
    $0.userDefaults.override(bool: true, forKey: "hasShownFirstLaunchOnboardingKey")
    $0.userDefaults.override(double: 0, forKey: "installationTimeKey")
    let defaults = $0.userDefaults
    $0.userDefaults.setDouble = { _, _ in }
    $0.userNotifications.delegate = { .finished }
    $0.userNotifications.getNotificationSettings = {
      (try? await Task.never()) ?? .init(authorizationStatus: .notDetermined)
    }
    $0.userNotifications.requestAuthorization = { _ in false }
  }
}
