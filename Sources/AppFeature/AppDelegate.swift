import AudioPlayerClient
import ComposableArchitecture
import ComposableUserNotifications
import Foundation
import SettingsFeature
import UserSettings
import Build

@Reducer
public struct AppDelegateReducer {
  public struct State: Equatable {
    @Shared(.build) var build = Build()
    public init() {}
  }

  public enum Action {
    case didFinishLaunching
    case didRegisterForRemoteNotifications(Result<Data, Error>)
    case userNotifications(UserNotificationClient.DelegateEvent)
  }

  @Dependency(\.apiClient) var apiClient
  @Dependency(\.audioPlayer) var audioPlayer
  @Dependency(\.dictionary.load) var loadDictionary
  @Dependency(\.remoteNotifications.register) var registerForRemoteNotifications
  @Dependency(\.applicationClient.setUserInterfaceStyle) var setUserInterfaceStyle
  @Dependency(\.userNotifications) var userNotifications

  public init() {}

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .didFinishLaunching:
        let userNotificationsEventStream = self.userNotifications.delegate()
        return .run { send in
          await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
              for await event in userNotificationsEventStream {
                await send(.userNotifications(event))
              }
            }

            group.addTask {
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

            group.addTask {
              _ = try self.loadDictionary(.en)
            }

            group.addTask {
              await self.audioPlayer.load(AudioPlayerClient.Sound.allCases)
            }

            group.addTask {
              @Shared(.userSettings) var userSettings = UserSettings()

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

      case .didRegisterForRemoteNotifications(.failure):
        return .none

      case let .didRegisterForRemoteNotifications(.success(tokenData)):
        let token = tokenData.map { String(format: "%02.2hhx", $0) }.joined()
        return .run { [build = state.build] _ in
          let settings = await self.userNotifications.getNotificationSettings()
          _ = try await self.apiClient.apiRequest(
            route: .push(
              .register(
                .init(
                  authorizationStatus: .init(rawValue: settings.authorizationStatus.rawValue),
                  build: build.number,
                  token: token
                )
              )
            )
          )
        } catch: { _, _ in
        }

      case let .userNotifications(.willPresentNotification(_, completionHandler)):
        return .run { _ in
          completionHandler(.banner)
        }

      case .userNotifications:
        return .none
      }
    }
  }
}
