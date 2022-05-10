import ApiClient
import AudioPlayerClient
import Build
import ComposableArchitecture
import ComposableUserNotifications
import DictionaryClient
import FileClient
import NotificationHelpers
import RemoteNotificationsClient
import SettingsFeature
import SharedModels
import TcaHelpers
import UIKit
import UserNotifications

public enum AppDelegateAction: Equatable {
  case didFinishLaunching
  case didRegisterForRemoteNotifications(Result<Data, NSError>)
  case userNotifications(UserNotificationClient.DelegateEvent)
  case userSettingsLoaded(Result<UserSettings, NSError>)
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
  var setUserInterfaceStyle: (UIUserInterfaceStyle) -> Effect<Never, Never>
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
      setUserInterfaceStyle: { _ in .failing("setUserInterfaceStyle") },
      userNotifications: .failing
    )
  #endif
}

let appDelegateReducer = Reducer<
  UserSettings, AppDelegateAction, AppDelegateEnvironment
> { state, action, environment in
  switch action {
  case .didFinishLaunching:
    return .merge(
      // Set notifications delegate
      environment.userNotifications.delegate
        .map(AppDelegateAction.userNotifications),

      .fireAndForget { @MainActor in
        switch await environment.userNotifications.getNotificationSettings().authorizationStatus {
        case .notDetermined, .provisional:
          _ = try? await environment.userNotifications.requestAuthorization(.provisional)
        case .authorized:
          _ = try? await environment.userNotifications.requestAuthorization([.alert, .sound])
        case .denied, .ephemeral:
          return
        @unknown default:
          return
        }

        await registerForRemoteNotifications(
          remoteNotifications: environment.remoteNotifications,
          userNotifications: environment.userNotifications
        )
      },

      // Preload dictionary
      Effect
        .catching { try environment.dictionary.load(.en) }
        .subscribe(on: environment.backgroundQueue)
        .fireAndForget(),

      .concatenate(
        .fireAndForget { @MainActor in
          await environment.audioPlayer.load(AudioPlayerClient.Sound.allCases)
        },

        environment.fileClient.loadUserSettings()
          .map(AppDelegateAction.userSettingsLoaded)
      )
    )

  case .didRegisterForRemoteNotifications(.failure):
    return .none

  case let .didRegisterForRemoteNotifications(.success(tokenData)):
    let token = tokenData.map { String(format: "%02.2hhx", $0) }.joined()
    return .fireAndForget { @MainActor in
      try? await environment.apiClient.apiRequest(
        route: .push(
          .register(
            .init(
              authorizationStatus: .init(
                rawValue: environment.userNotifications
                  .getNotificationSettings()
                  .authorizationStatus
                  .rawValue
              ),
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
    state = (try? result.get()) ?? state
    return .merge(
      .fireAndForget { 
        @MainActor
        [soundEffectsVolume = state.soundEffectsVolume,
         musicVolume = state.musicVolume] in

        await environment.audioPlayer.setGlobalVolumeForSoundEffects(
          soundEffectsVolume
        )
        await environment.audioPlayer.setGlobalVolumeForSoundEffects(
          environment.audioPlayer.secondaryAudioShouldBeSilencedHint()
          ? 0
          : musicVolume
        )
      },

      environment.setUserInterfaceStyle(state.colorScheme.userInterfaceStyle)
        // NB: This is necessary because UIKit needs at least one tick of the run loop before we
        //     can set the user interface style.
        .subscribe(on: environment.mainQueue)
        .fireAndForget()
    )
  }
}
