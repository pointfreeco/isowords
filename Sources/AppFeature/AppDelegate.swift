import ApiClient
import AudioPlayerClient
import Build
import ComposableArchitecture
import ComposableUserNotifications
import DictionaryClient
import RemoteNotificationsClient
import SettingsFeature
import SharedModels
import UserNotifications

public enum AppDelegateAction: Equatable {
  case didFinishLaunching
  case didRegisterForRemoteNotifications(Result<Data, NSError>)
  case userNotifications(UserNotificationClient.DelegateEvent)
}

struct AppDelegateEnvironment {
  var apiClient: ApiClient
  var audioPlayer: AudioPlayerClient
  var backgroundQueue: AnySchedulerOf<DispatchQueue>
  var build: Build
  var dictionary: DictionaryClient
  var mainQueue: AnySchedulerOf<DispatchQueue>
  var remoteNotifications: RemoteNotificationsClient
  var userNotifications: UserNotificationClient

  #if DEBUG
    static let failing = Self(
      apiClient: .failing,
      audioPlayer: .failing,
      backgroundQueue: .failing("backgroundQueue"),
      build: .failing,
      dictionary: .failing,
      mainQueue: .failing("mainQueue"),
      remoteNotifications: .failing,
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
              mainQueue: environment.mainQueue,
              remoteNotifications: environment.remoteNotifications,
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

      // Preload sounds
      environment.audioPlayer.load(AudioPlayerClient.Sound.allCases)
        .fireAndForget(),

      environment.audioPlayer.setGlobalVolumeForMusic(
        environment.audioPlayer.secondaryAudioShouldBeSilencedHint()
          ? 0
          : state.musicVolume
      )
      .fireAndForget()
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
      .fireAndForget()

  case let .userNotifications(.willPresentNotification(_, completionHandler)):
    return .fireAndForget {
      completionHandler(.banner)
    }

  case .userNotifications:
    return .none
  }
}
