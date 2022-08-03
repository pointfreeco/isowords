import AudioPlayerClient
import ComposableArchitecture
import ComposableUserNotifications
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
  @Dependency(\.applicationClient) var applicationClient
  @Dependency(\.audioPlayer) var audioPlayer
  @Dependency(\.build) var build
  @Dependency(\.dictionary) var dictionary
  @Dependency(\.fileClient) var fileClient
  @Dependency(\.remoteNotifications) var remoteNotifications
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
            await self.remoteNotifications.register()
          }

          group.addTask {
            _ = try self.dictionary.load(.en)
          }

          group.addTask {
            await self.audioPlayer.load(AudioPlayerClient.Sound.allCases)
          }

          group.addTask {
            await send(
              .userSettingsLoaded(
                TaskResult { try await self.fileClient.loadUserSettings() }
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
                build: self.build.number(),
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
          await self.applicationClient.setUserInterfaceStyle(state.colorScheme.userInterfaceStyle)
        _ = await (setSoundEffects, setMusic, setUI)
      }
    }
  }
}
