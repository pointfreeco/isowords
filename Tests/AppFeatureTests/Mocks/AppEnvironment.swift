import AppFeature
import ClientModels
import ComposableArchitecture
import Foundation
import Overture
import SettingsFeature
import UserDefaultsClient

extension DependencyValues {
  mutating func didFinishLaunching() {
    self.audioPlayer.load = { _ in }
    self.audioPlayer.secondaryAudioShouldBeSilencedHint = { false }
    self.audioPlayer.setGlobalVolumeForMusic = { _ in }
    self.audioPlayer.setGlobalVolumeForSoundEffects = { _ in }
    self.applicationClient.setUserInterfaceStyle = { _ in }
    self.database.migrate = {}
    self.dictionary.load = { _ in false }
    self.gameCenter.localPlayer.authenticate = {}
    self.gameCenter.localPlayer.listener = { .finished }
    self.mainQueue = .immediate
    self.mainRunLoop = .immediate
    self.serverConfig.refresh = { .init() }
    self.storeKit.observer = { .finished }
    self.userDefaults.override(bool: true, forKey: "hasShownFirstLaunchOnboardingKey")
    self.userDefaults.override(double: 0, forKey: "installationTimeKey")
    self.userDefaults.setDouble = { _, _ in }
    self.userNotifications.delegate = { .finished }
    self.userNotifications.getNotificationSettings = {
      (try? await Task.never()) ?? .init(authorizationStatus: .notDetermined)
    }
    self.userNotifications.requestAuthorization = { _ in false }
  }
}
