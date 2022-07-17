import ApiClient
import AudioPlayerClient
import Build
import ComposableArchitecture
import ComposableUserNotifications
import DictionaryClient
import FileClient
import RemoteNotificationsClient
import SettingsFeature
import SharedModels
import TcaHelpers
import UIKit
import UserNotifications
import XCTestDynamicOverlay

public enum AppDelegateAction: Equatable {
  case didFinishLaunching
  case didRegisterForRemoteNotifications(Result<Data, NSError>)
  case userNotifications(UserNotificationClient.DelegateEvent)
  case userSettingsLoaded(TaskResult<UserSettings>)
}

struct AppDelegateEnvironment {
  var apiClient: ApiClient
  var audioPlayer: AudioPlayerClient
  var backgroundQueue: AnySchedulerOf<DispatchQueue>
  var build: Build
  var dictionary: DictionaryClient
  var fileClient: FileClient
  var mainQueue: AnySchedulerOf<DispatchQueue>
  var remoteNotifications: RemoteNotificationsClient
  var setUserInterfaceStyleAsync: @Sendable (UIUserInterfaceStyle) async -> Void
  var userNotifications: UserNotificationClient

  #if DEBUG
    static let failing = Self(
      apiClient: .failing,
      audioPlayer: .failing,
      backgroundQueue: .failing("backgroundQueue"),
      build: .failing,
      dictionary: .failing,
      fileClient: .failing,
      mainQueue: .failing("mainQueue"),
      remoteNotifications: .failing,
      setUserInterfaceStyleAsync: XCTUnimplemented("\(Self.self).setUserInterfaceStyleAsync"),
      userNotifications: .failing
    )
  #endif
}

let appDelegateReducer = Reducer<
  UserSettings, AppDelegateAction, AppDelegateEnvironment
> { state, action, environment in
  switch action {
  case .didFinishLaunching:
    return .run { send in
      await withThrowingTaskGroup(of: Void.self) { group in
        group.addTask {
          for await event in environment.userNotifications.delegateAsync() {
            await send(.userNotifications(event))
          }
        }

        group.addTask {
          let settings = await environment.userNotifications.getNotificationSettingsAsync()
          switch settings.authorizationStatus {
          case .authorized:
            guard
              try await environment.userNotifications.requestAuthorizationAsync([.alert, .sound])
            else { return }
          case .notDetermined, .provisional:
            guard try await environment.userNotifications.requestAuthorizationAsync(.provisional)
            else { return }
          default:
            return
          }
          await environment.remoteNotifications.registerAsync()
        }

        group.addTask {
          _ = try environment.dictionary.load(.en)
        }

        group.addTask {
          await environment.audioPlayer.loadAsync(AudioPlayerClient.Sound.allCases)
        }

        group.addTask {
          await send(
            .userSettingsLoaded(
              TaskResult { try await environment.fileClient.loadUserSettingsAsync() }
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
      let settings = await environment.userNotifications.getNotificationSettingsAsync()
      _ = try await environment.apiClient.apiRequestAsync(
        route: .push(
          .register(
            .init(
              authorizationStatus: .init(rawValue: settings.authorizationStatus.rawValue),
              build: environment.build.number(),
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
        await environment.audioPlayer.setGlobalVolumeForSoundEffectsAsync(state.soundEffectsVolume)
      async let setMusic: Void = await environment.audioPlayer.setGlobalVolumeForMusicAsync(
        environment.audioPlayer.secondaryAudioShouldBeSilencedHintAsync()
          ? 0
          : state.musicVolume
      )
      async let setUI: Void =
        await environment.setUserInterfaceStyleAsync(state.colorScheme.userInterfaceStyle)
    }
  }
}
