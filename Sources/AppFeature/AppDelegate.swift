import AudioPlayerClient
import ComposableArchitecture
import ComposableUserNotifications
import Foundation
import SettingsFeature

public struct AppDelegateReducer: ReducerProtocol {
  public typealias State = UserSettings

  public enum Action: Equatable {
    case didFinishLaunching
    case didRegisterForRemoteNotifications(TaskResult<Data>)
    case userNotifications(UserNotificationClient.DelegateEvent)
    case userSettingsLoaded(TaskResult<UserSettings>)
  }

  @Dependency(\.apiClient) var apiClient
  @Dependency(\.audioPlayer) var audioPlayer
  @Dependency(\.build.number) var buildNumber
//  @Dependency(\.fileClient) var fileClient
  @Dependency(\.persistenceClient) var persistenceClient
  @Dependency(\.dictionary.load) var loadDictionary
  @Dependency(\.remoteNotifications.register) var registerForRemoteNotifications
  @Dependency(\.applicationClient.setUserInterfaceStyle) var setUserInterfaceStyle
  @Dependency(\.userNotifications) var userNotifications

  public init() {}

  public func reduce(into state: inout State, action: Action) -> Effect<Action, Never> {
    switch action {
    case .didFinishLaunching:
      return .run { send in
        await withThrowingTaskGroup(of: Void.self) { group in
          group.addTask {
            for await event in self.userNotifications.delegate() {
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
            await send(
              .userSettingsLoaded(
//                TaskResult { try await self.fileClient.loadUserSettings() }
                TaskResult { try await self.persistenceClient.userSettings() }
              )
            )
          }
        }
      }

    case .didRegisterForRemoteNotifications(.failure):
      return .none

    case let .didRegisterForRemoteNotifications(.success(tokenData)):
      let token = tokenData.map { String(format: "%02.2hhx", $0) }.joined()
      return .fireAndForget {
        let settings = await self.userNotifications.getNotificationSettings()
        _ = try await self.apiClient.apiRequest(
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

    case let .userNotifications(.willPresentNotification(_, completionHandler)):
      return .fireAndForget {
        completionHandler(.banner)
      }

    case .userNotifications:
      return .none

    case let .userSettingsLoaded(result):
      state = (try? result.value) ?? state
      return .fireAndForget { [state] in
        async let setSoundEffects: Void =
          await self.audioPlayer.setGlobalVolumeForSoundEffects(state.soundEffectsVolume)
        async let setMusic: Void = await self.audioPlayer.setGlobalVolumeForMusic(
          self.audioPlayer.secondaryAudioShouldBeSilencedHint()
            ? 0
            : state.musicVolume
        )
        async let setUI: Void =
          await self.setUserInterfaceStyle(state.colorScheme.userInterfaceStyle)
        _ = await (setSoundEffects, setMusic, setUI)
      }
    }
  }
}
