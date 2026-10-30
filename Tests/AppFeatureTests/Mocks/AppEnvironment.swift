import AppFeature
import ClientModels
import ComposableArchitecture
import Dependencies
import FileClient
import Foundation
import Overture
import SettingsFeature
import UserDefaultsClient

struct MockError: Error {}

extension DependencyValues {
  mutating func didFinishLaunching() {
    self.apiClient.authenticate = { _ in throw MockError() }
    self.audioPlayer.load = { _ in }
    self.audioPlayer.loop = { _ in }
    self.audioPlayer.play = { _ in }
    self.audioPlayer.secondaryAudioShouldBeSilencedHint = { false }
    self.audioPlayer.setGlobalVolumeForMusic = { _ in }
    self.audioPlayer.setGlobalVolumeForSoundEffects = { _ in }
    self.audioPlayer.stop = { _ in }
    self.applicationClient.setUserInterfaceStyle = { _ in }
    self.database.migrate = {}
    self.deviceId.id = { .deviceId }
    self.dictionary.load = { _ in false }
    self.feedbackGenerator = .noop
    self.fileClient.load = { @Sendable _ in throw MockError() }
    self.gameCenter.localPlayer.authenticate = {}
    self.gameCenter.localPlayer.listener = { .finished }
    self.gameCenter.localPlayer.localPlayer = { .notAuthenticated }
    self.gameCenter.turnBasedMatch.loadMatches = { [] }
    self.lowPowerMode.start = { .finished }
    self.serverConfig.config = { .init() }
    self.serverConfig.refresh = { .init() }
    self.storeKit.observer = { .finished }
    self.userDefaults.override(bool: true, forKey: "hasShownFirstLaunchOnboardingKey")
    self.userDefaults.override(double: 0, forKey: "installationTimeKey")
    self.userDefaults.override(integer: 0, forKey: "multiplayerOpensCount")
    self.userDefaults.setDouble = { _, _ in }
    self.userDefaults.setInteger = { _, _ in }
    self.userNotifications.delegate = { .finished }
    self.userNotifications.getNotificationSettings = {
      .init(authorizationStatus: .notDetermined)
    }
    self.userNotifications.requestAuthorization = { _ in false }
  }
}
