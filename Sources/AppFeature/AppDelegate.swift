import AudioPlayerClient
import ComposableArchitecture
import ComposableUserNotifications
import Dependencies
import Foundation
import SettingsFeature

@Feature
public struct AppDelegateReducer {
  public struct State {
    public init() {}
  }

  public enum Action {
    case didRegisterForRemoteNotifications(Result<Data, Error>)
  }

  public enum DidReceiveNotificationResponse: FeatureEventKey {
    public typealias Value = UserNotificationClient.Notification.Response
  }

  @Dependency(\.apiClient) var apiClient
  @Dependency(\.audioPlayer) var audioPlayer
  @Dependency(\.build.number) var buildNumber
  @Dependency(\.dictionary.load) var loadDictionary
  @Dependency(\.remoteNotifications.register) var registerForRemoteNotifications
  @Dependency(\.applicationClient.setUserInterfaceStyle) var setUserInterfaceStyle
  @Dependency(\.userNotifications) var userNotifications
  @Dependency(\.userSettings) var userSettings

  public init() {}

  public var body: some Feature {
    Update { state, action in
      switch action {
      case .didRegisterForRemoteNotifications(.failure):
        break

      case let .didRegisterForRemoteNotifications(.success(tokenData)):
        let token = tokenData.map { String(format: "%02.2hhx", $0) }.joined()
        store.addTask {
          let settings = await self.userNotifications.getNotificationSettings()
          _ = try? await self.apiClient.apiRequest(
            route: .push(
              .register(
                .init(
                  authorizationStatus: .init(rawValue: settings.authorizationStatus.rawValue),
                  build: self.buildNumber(),
                  token: token
                )
              )
            )
          )
        }
      }
    }
    .onMount { _ in
      let userNotificationsEventStream = self.userNotifications.delegate()
      store.addTask {
        for await event in userNotificationsEventStream {
          switch event {
          case let .didReceiveResponse(response, completionHandler):
            try store.post(key: DidReceiveNotificationResponse.self, value: response)
            completionHandler()

          case .openSettingsForNotification:
            break

          case let .willPresentNotification(_, completionHandler):
            completionHandler(.banner)
          }
        }
      }
      store.addTask {
        let settings = await self.userNotifications.getNotificationSettings()
        switch settings.authorizationStatus {
        case .authorized:
          guard
            try await self.userNotifications.requestAuthorization([.alert, .sound])
          else { return }
        case .notDetermined, .provisional:
          guard try await self.userNotifications.requestAuthorization(.provisional)
          else { return }
        default:
          return
        }
        await self.registerForRemoteNotifications()
      }
      store.addTask {
        _ = try self.loadDictionary(.en)
      }
      store.addTask {
        await self.audioPlayer.load(AudioPlayerClient.Sound.allCases)
      }
      store.addTask {
        await self.audioPlayer.setGlobalVolumeForSoundEffects(userSettings.soundEffectsVolume)
        await self.audioPlayer.setGlobalVolumeForMusic(
          self.audioPlayer.secondaryAudioShouldBeSilencedHint()
            ? 0
            : userSettings.musicVolume
        )
        await self.setUserInterfaceStyle(userSettings.colorScheme.userInterfaceStyle)
      }
    }
  }
}
