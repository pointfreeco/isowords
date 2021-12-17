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

public enum AppDelegateAction {
  case didFinishLaunching
  case didRegisterForRemoteNotifications(Result<Data, Error>)
  case userNotifications(UserNotificationClient.DelegateEvent)
  case userSettingsLoaded(Result<UserSettings, Error>)
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

      environment.userNotifications.getNotificationSettings
        .receive(on: environment.mainQueue)
        .flatMap { settings in
          [.notDetermined, .provisional].contains(settings.authorizationStatus)
            ? environment.userNotifications.requestAuthorization(.provisional)
            : settings.authorizationStatus == .authorized
              ? environment.userNotifications.requestAuthorization([.alert, .sound])
              : .none
        }
        .ignoreFailure()
        .flatMap { successful in
          successful
            ? Effect.registerForRemoteNotifications(
              remoteNotifications: environment.remoteNotifications,
              scheduler: environment.mainQueue,
              userNotifications: environment.userNotifications
            )
            : .none
        }
        .eraseToEffect()
        .fireAndForget(),

      // Preload dictionary
      Effect
        .catching { try environment.dictionary.load(.en) }
        .subscribe(on: environment.backgroundQueue)
        .fireAndForget(),

      .concatenate(
        environment.audioPlayer.load(AudioPlayerClient.Sound.allCases)
          .fireAndForget(),

        environment.fileClient.loadUserSettings()
          .map(AppDelegateAction.userSettingsLoaded)
      )
    )

  case .didRegisterForRemoteNotifications(.failure):
    return .none

  case let .didRegisterForRemoteNotifications(.success(tokenData)):
    let token = tokenData.map { String(format: "%02.2hhx", $0) }.joined()
    return environment.userNotifications.getNotificationSettings
      .flatMap { settings in
        environment.apiClient.apiRequest(
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
      .receive(on: environment.mainQueue)
      .fireAndForget()

  case let .userNotifications(.willPresentNotification(_, completionHandler)):
    return .fireAndForget {
      completionHandler(.banner)
    }

  case .userNotifications:
    return .none

  case let .userSettingsLoaded(result):
    state = (try? result.get()) ?? state
    return .merge(
      environment.audioPlayer.setGlobalVolumeForSoundEffects(
        state.soundEffectsVolume
      )
      .fireAndForget(),

      environment.audioPlayer.setGlobalVolumeForSoundEffects(
        environment.audioPlayer.secondaryAudioShouldBeSilencedHint()
          ? 0
          : state.musicVolume
      )
      .fireAndForget(),

      environment.setUserInterfaceStyle(state.colorScheme.userInterfaceStyle)
        // NB: This is necessary because UIKit needs at least one tick of the run loop before we
        //     can set the user interface style.
        .subscribe(on: environment.mainQueue)
        .fireAndForget()
    )
  }
}
