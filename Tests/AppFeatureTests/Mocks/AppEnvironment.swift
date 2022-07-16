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
    $0.audioPlayer.loadAsync = { _ in }
    $0.backgroundQueue = .immediate
    $0.database.migrateAsync = {}
    $0.dictionary.load = { _ in false }
    $0.fileClient.loadAsync = { @Sendable _ in try await Task.never() }
    $0.gameCenter.localPlayer.authenticate = .none
    $0.gameCenter.localPlayer.authenticateAsync = {}
    $0.gameCenter.localPlayer.listenerAsync = { .finished }
    $0.mainQueue = .immediate
    $0.mainRunLoop = .immediate
    $0.serverConfig.refreshAsync = { .init() }
    $0.storeKit.observer = .none
    $0.userDefaults.override(bool: true, forKey: "hasShownFirstLaunchOnboardingKey")
    $0.userDefaults.override(double: 0, forKey: "installationTimeKey")
    let defaults = $0.userDefaults
    $0.userDefaults.setDoubleAsync = { _, _ in }
    $0.userNotifications.delegateAsync = { .finished }
    $0.userNotifications.getNotificationSettingsAsync = {
      (try? await Task.never()) ?? .init(authorizationStatus: .notDetermined)
    }
    $0.userNotifications.requestAuthorizationAsync = { _ in false }
  }
}
