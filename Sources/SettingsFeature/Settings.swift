import ApiClient
import AudioPlayerClient
import Build
import ComposableArchitecture
import ComposableStoreKit
import ComposableUserNotifications
import FeedbackGeneratorClient
import FileClient
import LocalDatabaseClient
import LowPowerModeClient
import RemoteNotificationsClient
import SceneKit
import ServerConfigClient
import SharedModels
import StatsFeature
import StoreKit
import SwiftUI
import SwiftUIHelpers
import TcaHelpers
import UIApplicationClient
import UserDefaultsClient
import UserNotifications

public struct UserSettings: Codable, Equatable {
  public var appIcon: AppIcon?
  public var colorScheme: ColorScheme
  public var enableGyroMotion: Bool
  public var enableHaptics: Bool
  public var enableReducedAnimation: Bool
  public var musicVolume: Float
  public var soundEffectsVolume: Float

  public enum ColorScheme: String, CaseIterable, Codable {
    case dark
    case light
    case system

    public var userInterfaceStyle: UIUserInterfaceStyle {
      switch self {
      case .dark:
        return .dark
      case .light:
        return .light
      case .system:
        return .unspecified
      }
    }
  }

  public init(
    appIcon: AppIcon? = nil,
    colorScheme: ColorScheme = .system,
    enableGyroMotion: Bool = true,
    enableHaptics: Bool = true,
    enableReducedAnimation: Bool = false,
    musicVolume: Float = 1,
    soundEffectsVolume: Float = 1
  ) {
    self.appIcon = appIcon
    self.colorScheme = colorScheme
    self.enableGyroMotion = enableGyroMotion
    self.enableHaptics = enableHaptics
    self.enableReducedAnimation = enableReducedAnimation
    self.musicVolume = musicVolume
    self.soundEffectsVolume = soundEffectsVolume
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.appIcon = try? container.decode(AppIcon.self, forKey: .appIcon)
    self.colorScheme = (try? container.decode(ColorScheme.self, forKey: .colorScheme)) ?? .system
    self.enableGyroMotion = (try? container.decode(Bool.self, forKey: .enableGyroMotion)) ?? true
    self.enableHaptics = (try? container.decode(Bool.self, forKey: .enableHaptics)) ?? true
    self.enableReducedAnimation =
      (try? container.decode(Bool.self, forKey: .enableReducedAnimation)) ?? false
    self.musicVolume = (try? container.decode(Float.self, forKey: .musicVolume)) ?? 1
    self.soundEffectsVolume = (try? container.decode(Float.self, forKey: .soundEffectsVolume)) ?? 1
  }
}

public struct DeveloperSettings: Equatable {
  public var currentBaseUrl: BaseUrl

  public init(currentBaseUrl: BaseUrl = .production) {
    self.currentBaseUrl = currentBaseUrl
  }

  public enum BaseUrl: String, CaseIterable {
    case localhost = "http://localhost:9876"
    case localhostTunnel = "https://pointfreeco-localhost.ngrok.io"
    case production = "https://www.isowords.xyz"
    case staging = "https://isowords-staging.herokuapp.com"

    var description: String {
      switch self {
      case .localhost:
        return "Localhost"
      case .localhostTunnel:
        return "Localhost Tunnel"
      case .production:
        return "Production"
      case .staging:
        return "Staging"
      }
    }

    var url: URL { URL(string: self.rawValue)! }
  }
}

public struct SettingsState: Equatable {
  public var alert: AlertState<SettingsAction>?
  public var buildNumber: Int?
  public var cubeShadowRadius: CGFloat
  public var developer: DeveloperSettings
  public var enableCubeShadow: Bool
  public var enableNotifications: Bool
  public var fullGameProduct: Result<StoreKitClient.Product, ProductError>?
  public var fullGamePurchasedAt: Date?
  public var isPurchasing: Bool
  public var isRestoring: Bool
  public var sendDailyChallengeReminder: Bool
  public var sendDailyChallengeSummary: Bool
  public var showSceneStatistics: Bool
  public var stats: StatsState
  public var userNotificationSettings: UserNotificationClient.Notification.Settings?
  public var userSettings: UserSettings

  public struct ProductError: Error, Equatable {}

  public init(
    alert: AlertState<SettingsAction>? = nil,
    buildNumber: Int? = nil,
    cubeShadowRadius: CGFloat = 50,
    developer: DeveloperSettings = DeveloperSettings(),
    enableCubeShadow: Bool = true,
    enableNotifications: Bool = false,
    fullGameProduct: Result<StoreKitClient.Product, ProductError>? = nil,
    fullGamePurchasedAt: Date? = nil,
    isPurchasing: Bool = false,
    isRestoring: Bool = false,
    sendDailyChallengeReminder: Bool = true,
    sendDailyChallengeSummary: Bool = true,
    showSceneStatistics: Bool = false,
    stats: StatsState = .init(),
    userNotificationSettings: UserNotificationClient.Notification.Settings? = nil,
    userSettings: UserSettings = UserSettings()
  ) {
    self.alert = alert
    self.buildNumber = buildNumber
    self.cubeShadowRadius = cubeShadowRadius
    self.developer = developer
    self.enableCubeShadow = enableCubeShadow
    self.enableNotifications = enableNotifications
    self.fullGameProduct = fullGameProduct
    self.fullGamePurchasedAt = fullGamePurchasedAt
    self.isPurchasing = isPurchasing
    self.isRestoring = isRestoring
    self.sendDailyChallengeReminder = sendDailyChallengeReminder
    self.sendDailyChallengeSummary = sendDailyChallengeSummary
    self.showSceneStatistics = showSceneStatistics
    self.stats = stats
    self.userNotificationSettings = userNotificationSettings
    self.userSettings = userSettings
  }

  public var isFullGamePurchased: Bool {
    return self.fullGamePurchasedAt != nil
  }
}

public enum SettingsAction: Equatable {
  case binding(BindingAction<SettingsState>)
  case currentPlayerRefreshed(Result<CurrentPlayerEnvelope, ApiError>)
  case didBecomeActive
  case leaveUsAReviewButtonTapped
  case onAppear
  case onDismiss
  case openSettingButtonTapped
  case paymentTransaction(StoreKitClient.PaymentTransactionObserverEvent)
  case productsResponse(Result<StoreKitClient.ProductsResponse, NSError>)
  case reportABugButtonTapped
  case restoreButtonTapped
  case stats(StatsAction)
  case tappedProduct(StoreKitClient.Product)
  case userNotificationAuthorizationResponse(Result<Bool, NSError>)
  case userNotificationSettingsResponse(UserNotificationClient.Notification.Settings)
}

public struct SettingsEnvironment {
  public var apiClient: ApiClient
  public var applicationClient: UIApplicationClient
  public var audioPlayer: AudioPlayerClient
  public var backgroundQueue: AnySchedulerOf<DispatchQueue>
  public var build: Build
  public var database: LocalDatabaseClient
  public var feedbackGenerator: FeedbackGeneratorClient
  public var fileClient: FileClient
  public var lowPowerMode: LowPowerModeClient
  public var mainQueue: AnySchedulerOf<DispatchQueue>
  public var remoteNotifications: RemoteNotificationsClient
  public var serverConfig: ServerConfigClient
  public var setUserInterfaceStyle: (UIUserInterfaceStyle) -> Effect<Never, Never>
  public var storeKit: StoreKitClient
  public var userDefaults: UserDefaultsClient
  public var userNotifications: UserNotificationClient

  public init(
    apiClient: ApiClient,
    applicationClient: UIApplicationClient,
    audioPlayer: AudioPlayerClient,
    backgroundQueue: AnySchedulerOf<DispatchQueue>,
    build: Build,
    database: LocalDatabaseClient,
    feedbackGenerator: FeedbackGeneratorClient,
    fileClient: FileClient,
    lowPowerMode: LowPowerModeClient,
    mainQueue: AnySchedulerOf<DispatchQueue>,
    remoteNotifications: RemoteNotificationsClient,
    serverConfig: ServerConfigClient,
    setUserInterfaceStyle: @escaping (UIUserInterfaceStyle) -> Effect<Never, Never>,
    storeKit: StoreKitClient,
    userDefaults: UserDefaultsClient,
    userNotifications: UserNotificationClient
  ) {
    self.apiClient = apiClient
    self.applicationClient = applicationClient
    self.audioPlayer = audioPlayer
    self.backgroundQueue = backgroundQueue
    self.build = build
    self.database = database
    self.feedbackGenerator = feedbackGenerator
    self.fileClient = fileClient
    self.lowPowerMode = lowPowerMode
    self.mainQueue = mainQueue
    self.remoteNotifications = remoteNotifications
    self.serverConfig = serverConfig
    self.setUserInterfaceStyle = setUserInterfaceStyle
    self.storeKit = storeKit
    self.userDefaults = userDefaults
    self.userNotifications = userNotifications
  }
}

#if DEBUG
  import XCTestDynamicOverlay

  extension SettingsEnvironment {
    public static let failing = Self(
      apiClient: .failing,
      applicationClient: .failing,
      audioPlayer: .failing,
      backgroundQueue: .failing("backgroundQueue"),
      build: .failing,
      database: .failing,
      feedbackGenerator: .failing,
      fileClient: .failing,
      lowPowerMode: .failing,
      mainQueue: .failing("mainQueue"),
      remoteNotifications: .failing,
      serverConfig: .failing,
      setUserInterfaceStyle: { _ in
        .failing("\(Self.self).setUserInterfaceStyle is unimplemented")
      },
      storeKit: .failing,
      userDefaults: .failing,
      userNotifications: .failing
    )

    public static let noop = Self(
      apiClient: .noop,
      applicationClient: .noop,
      audioPlayer: .noop,
      backgroundQueue: DispatchQueue.main.eraseToAnyScheduler(),
      build: .noop,
      database: .noop,
      feedbackGenerator: .noop,
      fileClient: .noop,
      lowPowerMode: .false,
      mainQueue: DispatchQueue.main.eraseToAnyScheduler(),
      remoteNotifications: .noop,
      serverConfig: .noop,
      setUserInterfaceStyle: { _ in .none },
      storeKit: .noop,
      userDefaults: .noop,
      userNotifications: .noop
    )
  }
#endif

public let settingsReducer = Reducer<SettingsState, SettingsAction, SettingsEnvironment>.combine(
  statsReducer.pullback(
    state: \.stats,
    action: /SettingsAction.stats,
    environment: {
      StatsEnvironment(
        audioPlayer: $0.audioPlayer,
        database: $0.database,
        feedbackGenerator: $0.feedbackGenerator,
        lowPowerMode: $0.lowPowerMode,
        mainQueue: $0.mainQueue
      )
    }
  ),

  Reducer { state, action, environment in
    struct DidBecomeActiveId: Hashable {}
    struct PaymentObserverId: Hashable {}
    struct UpdateRemoteSettingsId: Hashable {}

    switch action {
    case .binding(\.developer.currentBaseUrl):
      return .merge(
        environment.apiClient.setBaseUrl(state.developer.currentBaseUrl.url).fireAndForget(),
        environment.apiClient.logout().fireAndForget()
      )

    case .binding(\.enableNotifications):
      guard
        state.enableNotifications,
        let userNotificationSettings = state.userNotificationSettings
      else {
        // TODO: API request to opt out of all notifications
        state.enableNotifications = false
        return .none
      }

      switch userNotificationSettings.authorizationStatus {
      case .notDetermined, .provisional:
        state.enableNotifications = true
        return environment.userNotifications.requestAuthorization([.alert, .sound])
          .mapError { $0 as NSError }
          .receive(on: environment.mainQueue.animation())
          .catchToEffect()
          .map(SettingsAction.userNotificationAuthorizationResponse)

      case .denied:
        state.alert = .userNotificationAuthorizationDenied
        state.enableNotifications = false
        return .none

      case .authorized:
        state.enableNotifications = true
        return .init(value: .userNotificationAuthorizationResponse(.success(true)))

      case .ephemeral:
        state.enableNotifications = true
        return .none

      @unknown default:
        return .none
      }

    case .binding(\.sendDailyChallengeReminder):
      return Effect.concatenate(
        environment.apiClient.apiRequest(
          route: .push(
            .updateSetting(
              .init(
                notificationType: .dailyChallengeEndsSoon,
                sendNotifications: state.sendDailyChallengeReminder
              )
            )
          )
        )
        .fireAndForget(),
        environment.apiClient.refreshCurrentPlayer()
          .catchToEffect()
          .map(SettingsAction.currentPlayerRefreshed)
      )
      .debounce(id: UpdateRemoteSettingsId(), for: 1, scheduler: environment.mainQueue)

    case .binding(\.sendDailyChallengeSummary):
      return Effect.concatenate(
        environment.apiClient.apiRequest(
          route: .push(
            .updateSetting(
              .init(
                notificationType: .dailyChallengeReport,
                sendNotifications: state.sendDailyChallengeSummary
              )
            )
          )
        )
        .fireAndForget(),
        environment.apiClient.refreshCurrentPlayer()
          .catchToEffect()
          .map(SettingsAction.currentPlayerRefreshed)
      )
      .debounce(id: UpdateRemoteSettingsId(), for: 1, scheduler: environment.mainQueue)

    case .binding(\.userSettings.appIcon):
      return environment.applicationClient
        .setAlternateIconName(state.userSettings.appIcon?.rawValue)
        .fireAndForget()

    case .binding(\.userSettings.colorScheme):
      return environment.setUserInterfaceStyle(state.userSettings.colorScheme.userInterfaceStyle)
        .fireAndForget()

    case .binding(\.userSettings.musicVolume):
      return environment.audioPlayer.setGlobalVolumeForMusic(state.userSettings.musicVolume)
        .fireAndForget()

    case .binding(\.userSettings.soundEffectsVolume):
      return environment.audioPlayer
        .setGlobalVolumeForSoundEffects(state.userSettings.soundEffectsVolume)
        .fireAndForget()

    case .binding:
      return .none

    case let .currentPlayerRefreshed(.success(envelope)):
      state.isRestoring = false
      state.fullGamePurchasedAt = envelope.appleReceipt?.receipt.originalPurchaseDate
      state.sendDailyChallengeReminder = envelope.player.sendDailyChallengeReminder
      state.sendDailyChallengeSummary = envelope.player.sendDailyChallengeSummary
      return .none

    case .currentPlayerRefreshed(.failure):
      state.isRestoring = false
      return .none

    case .didBecomeActive:
      return environment.userNotifications.getNotificationSettings
        .receive(on: environment.mainQueue)
        .eraseToEffect()
        .map(SettingsAction.userNotificationSettingsResponse)

    case .leaveUsAReviewButtonTapped:
      return environment.applicationClient
        .open(environment.serverConfig.config().appStoreReviewUrl, [:])
        .ignoreOutput()
        .eraseToEffect()
        .fireAndForget()

    case .onAppear:
      state.fullGamePurchasedAt =
        environment.apiClient.currentPlayer()?
        .appleReceipt?
        .receipt
        .originalPurchaseDate
      state.buildNumber = environment.build.number()
      state.userSettings.appIcon = environment.applicationClient.alternateIconName()
        .flatMap(AppIcon.init(rawValue:))

      let loadProductsEffect: Effect<SettingsAction, Never>
      if state.isFullGamePurchased {
        loadProductsEffect = .none
      } else {
        loadProductsEffect = environment.storeKit
          .fetchProducts([
            environment.serverConfig.config().productIdentifiers.fullGame
          ])
          .mapError { $0 as NSError }
          .receive(on: environment.mainQueue.animation())
          .catchToEffect()
          .map(SettingsAction.productsResponse)
      }

      if let baseUrl = DeveloperSettings.BaseUrl(
        rawValue: environment.apiClient.baseUrl().absoluteString)
      {
        state.developer.currentBaseUrl = baseUrl
      }

      return .merge(
        loadProductsEffect,

        environment.storeKit.observer
          .receive(on: environment.mainQueue.animation())
          .map(SettingsAction.paymentTransaction)
          .eraseToEffect()
          .cancellable(id: PaymentObserverId()),

        environment.userNotifications.getNotificationSettings
          .receive(on: environment.mainQueue.animation())
          .eraseToEffect()
          .map(SettingsAction.userNotificationSettingsResponse),

        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
          .map { _ in .didBecomeActive }
          .eraseToEffect()
          .cancellable(id: DidBecomeActiveId())
      )

    case .onDismiss:
      return .merge(
        .cancel(id: DidBecomeActiveId()),
        .cancel(id: PaymentObserverId())
      )

    case .paymentTransaction(.removedTransactions):
      state.isPurchasing = false
      return environment.apiClient.refreshCurrentPlayer()
        .receive(on: environment.mainQueue.animation())
        .catchToEffect()
        .map(SettingsAction.currentPlayerRefreshed)

    case .paymentTransaction:
      return .none

    case .openSettingButtonTapped:
      return URL(string: environment.applicationClient.openSettingsURLString())
        .map {
          environment.applicationClient.open($0, [:])
            .ignoreOutput()
            .eraseToEffect()
            .fireAndForget()
        }
        ?? .none

    case let .productsResponse(.success(response)):
      state.fullGameProduct =
        response.products
        .first {
          $0.productIdentifier == environment.serverConfig.config().productIdentifiers.fullGame
        }
        .map(Result.success)
        ?? Result.failure(.init())
      return .none

    case .productsResponse(.failure):
      state.fullGameProduct = .failure(.init())
      return .none

    case .reportABugButtonTapped:
      var components = URLComponents()
      components.scheme = "mailto"
      components.path = "support@pointfree.co"
      components.queryItems = [
        URLQueryItem(name: "subject", value: "I found a bug in isowords"),
        URLQueryItem(
          name: "body",
          value: """


            ---
            Build: \(environment.build.number()) (\(environment.build.gitSha()))
            \(environment.apiClient.currentPlayer()?.player.id.rawValue.uuidString ?? "")
            """
        ),
      ]

      return environment.applicationClient
        .open(components.url!, [:])
        .ignoreOutput()
        .eraseToEffect()
        .fireAndForget()

    case .restoreButtonTapped:
      state.isRestoring = true
      return environment.storeKit.restoreCompletedTransactions()
        .fireAndForget()

    case .stats:
      return .none

    case let .tappedProduct(product):
      state.isPurchasing = true
      let payment = SKMutablePayment()
      payment.productIdentifier = product.productIdentifier
      payment.quantity = 1
      return environment.storeKit.addPayment(payment)
        .fireAndForget()

    case let .userNotificationAuthorizationResponse(.success(granted)):
      state.enableNotifications = granted
      return granted
        ? environment.remoteNotifications.register()
          .fireAndForget()
        : .none

    case .userNotificationAuthorizationResponse:
      return .none

    case let .userNotificationSettingsResponse(settings):
      state.userNotificationSettings = settings
      state.enableNotifications = settings.authorizationStatus == .authorized
      return .none
    }
  }
  .binding(action: /SettingsAction.binding)
)
.onChange(of: \.userSettings) { userSettings, _, _, environment in
  struct SaveDebounceId: Hashable {}

  return environment.fileClient
    .saveUserSettings(userSettings: userSettings, on: environment.backgroundQueue)
    .fireAndForget()
    .debounce(id: SaveDebounceId(), for: .seconds(1), scheduler: environment.mainQueue)
}

extension AlertState where Action == SettingsAction {
  static let userNotificationAuthorizationDenied = Self(
    title: .init("Permission Denied"),
    message: .init(
      """
      Turn on notifications in iOS settings.
      """),
    primaryButton: .default(.init("Ok"), send: .binding(.set(\.alert, nil))),
    secondaryButton: .default(.init("Open Settings"), send: .openSettingButtonTapped),
    onDismiss: .binding(.set(\.alert, nil))
  )
}
