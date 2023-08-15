import ApiClient
import Build
import ComposableArchitecture
import ComposableStoreKit
import ComposableUserNotifications
import RemoteNotificationsClient
import SharedModels
import StatsFeature
import StoreKit
import UIApplicationClient

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

public struct Settings: ReducerProtocol {
  public struct State: Equatable {
    @BindingState public var alert: AlertState<Action>?
    public var buildNumber: Build.Number?
    @BindingState public var cubeShadowRadius: CGFloat
    @BindingState public var developer: DeveloperSettings
    @BindingState public var enableCubeShadow: Bool
    @BindingState public var enableNotifications: Bool
    public var fullGameProduct: Result<StoreKitClient.Product, ProductError>?
    public var fullGamePurchasedAt: Date?
    public var isPurchasing: Bool
    public var isRestoring: Bool
    @BindingState public var sendDailyChallengeReminder: Bool
    @BindingState public var sendDailyChallengeSummary: Bool
    @BindingState public var showSceneStatistics: Bool
    public var stats: Stats.State
    public var userNotificationSettings: UserNotificationClient.Notification.Settings?
    @BindingState public var userSettings: UserSettings

    public struct ProductError: Error, Equatable {}

    public init(
      alert: AlertState<Action>? = nil,
      buildNumber: Build.Number? = nil,
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
      stats: Stats.State = .init(),
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

  public enum Action: BindableAction, Equatable {
    case binding(BindingAction<State>)
    case currentPlayerRefreshed(TaskResult<CurrentPlayerEnvelope>)
    case didBecomeActive
    case leaveUsAReviewButtonTapped
    case onDismiss
    case openSettingButtonTapped
    case paymentTransaction(StoreKitClient.PaymentTransactionObserverEvent)
    case productsResponse(TaskResult<StoreKitClient.ProductsResponse>)
    case reportABugButtonTapped
    case restoreButtonTapped
    case stats(Stats.Action)
    case tappedProduct(StoreKitClient.Product)
    case task
    case userNotificationAuthorizationResponse(TaskResult<Bool>)
    case userNotificationSettingsResponse(UserNotificationClient.Notification.Settings)
  }

  @Dependency(\.apiClient) var apiClient
  @Dependency(\.applicationClient) var applicationClient
  @Dependency(\.audioPlayer) var audioPlayer
  @Dependency(\.build) var build
  @Dependency(\.fileClient) var fileClient
  @Dependency(\.mainQueue) var mainQueue
  @Dependency(\.remoteNotifications.register) var registerForRemoteNotifications
  @Dependency(\.serverConfig.config) var serverConfig
  @Dependency(\.storeKit) var storeKit
  @Dependency(\.userNotifications) var userNotifications

  public init() {}

  private enum CancelID {
    case paymentObserver
    case updateRemoveSettings
  }

  public var body: some ReducerProtocol<State, Action> {
    CombineReducers {
      BindingReducer()
        .onChange(of: \.developer.currentBaseUrl.url) { _, url in
          Reduce { _, _ in
            .run { _ in
              await self.apiClient.setBaseUrl(url)
              await self.apiClient.logout()
            }
          }
        }
        .onChange(of: \.enableNotifications) { _, _ in
          Reduce { state, _ in
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
              return .run { send in
                await send(
                  .userNotificationAuthorizationResponse(
                    TaskResult {
                      try await self.userNotifications.requestAuthorization([.alert, .sound])
                    }
                  )
                )
              }
              .animation()

            case .denied:
              state.alert = .userNotificationAuthorizationDenied
              state.enableNotifications = false
              return .none

            case .authorized:
              state.enableNotifications = true
              return .send(.userNotificationAuthorizationResponse(.success(true)))

            case .ephemeral:
              state.enableNotifications = true
              return .none

            @unknown default:
              return .none
            }
          }
        }
        .onChange(of: \.sendDailyChallengeReminder) { _, _ in
          Reduce { state, _ in
            .run { [sendDailyChallengeReminder = state.sendDailyChallengeReminder] send in
              _ = try await self.apiClient.apiRequest(
                route: .push(
                  .updateSetting(
                    .init(
                      notificationType: .dailyChallengeEndsSoon,
                      sendNotifications: sendDailyChallengeReminder
                    )
                  )
                )
              )
              await send(
                .currentPlayerRefreshed(
                  TaskResult { try await self.apiClient.refreshCurrentPlayer() }
                )
              )
            }
            .debounce(id: CancelID.updateRemoveSettings, for: 1, scheduler: self.mainQueue)
          }
        }
        .onChange(of: \.sendDailyChallengeSummary) { _, _ in
          Reduce { state, _ in
            .run { [sendDailyChallengeSummary = state.sendDailyChallengeSummary] send in
              _ = try await self.apiClient.apiRequest(
                route: .push(
                  .updateSetting(
                    .init(
                      notificationType: .dailyChallengeReport,
                      sendNotifications: sendDailyChallengeSummary
                    )
                  )
                )
              )
              await send(
                .currentPlayerRefreshed(
                  TaskResult { try await self.apiClient.refreshCurrentPlayer() }
                )
              )
            }
            .debounce(id: CancelID.updateRemoveSettings, for: 1, scheduler: self.mainQueue)
          }
        }
        .onChange(of: \.userSettings) { _, userSettings in
          Reduce { _, _ in
            .run { _ in
              try await self.applicationClient.setAlternateIconName(userSettings.appIcon?.rawValue)
              await self.applicationClient.setUserInterfaceStyle(
                userSettings.colorScheme.userInterfaceStyle)
              await self.audioPlayer.setGlobalVolumeForMusic(userSettings.musicVolume)
              await self.audioPlayer.setGlobalVolumeForSoundEffects(userSettings.soundEffectsVolume)
            }
          }
        }

      Reduce { state, action in
        switch action {
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
          return .run { send in
            await send(
              .userNotificationSettingsResponse(
                self.userNotifications.getNotificationSettings()
              )
            )
          }

        case .leaveUsAReviewButtonTapped:
          return .run { _ in
            _ = await self.applicationClient
              .open(self.serverConfig().appStoreReviewUrl, [:])
          }

        case .onDismiss:
          return .cancel(id: CancelID.paymentObserver)

        case .paymentTransaction(.removedTransactions):
          state.isPurchasing = false
          return .run { send in
            await send(
              .currentPlayerRefreshed(
                TaskResult { try await self.apiClient.refreshCurrentPlayer() }
              )
            )
          }
          .animation()

        case let .paymentTransaction(.restoreCompletedTransactionsFinished(transactions)):
          state.isRestoring = false
          state.alert = transactions.isEmpty ? .noRestoredPurchases : nil
          return .none

        case .paymentTransaction(.restoreCompletedTransactionsFailed):
          state.isRestoring = false
          state.alert = .restoredPurchasesFailed
          return .none

        case let .paymentTransaction(.updatedTransactions(transactions)):
          if transactions.contains(where: { $0.error != nil }) {
            state.isPurchasing = false
          }
          return .none

        case .openSettingButtonTapped:
          return .run { _ in
            guard
              let url = await URL(string: self.applicationClient.openSettingsURLString())
            else { return }
            _ = await self.applicationClient.open(url, [:])
          }

        case let .productsResponse(.success(response)):
          state.fullGameProduct =
            response.products
            .first {
              $0.productIdentifier == self.serverConfig().productIdentifiers.fullGame
            }
            .map(Result.success)
            ?? Result.failure(.init())
          return .none

        case .productsResponse(.failure):
          state.fullGameProduct = .failure(.init())
          return .none

        case .reportABugButtonTapped:
          return .run { _ in
            let currentPlayer = self.apiClient.currentPlayer()
            var components = URLComponents()
            components.scheme = "mailto"
            components.path = "support@pointfree.co"
            components.queryItems = [
              URLQueryItem(name: "subject", value: "I found a bug in isowords"),
              URLQueryItem(
                name: "body",
                value: """


                  ---
                  Build: \(self.build.number()) (\(self.build.gitSha()))
                  \(currentPlayer?.player.id.rawValue.uuidString ?? "")
                  """
              ),
            ]

            _ = await self.applicationClient.open(components.url!, [:])
          }

        case .restoreButtonTapped:
          state.isRestoring = true
          return .run { _ in await self.storeKit.restoreCompletedTransactions() }

        case .stats:
          return .none

        case let .tappedProduct(product):
          state.isPurchasing = true
          return .run { _ in
            let payment = SKMutablePayment()
            payment.productIdentifier = product.productIdentifier
            payment.quantity = 1
            await self.storeKit.addPayment(payment)
          }

        case .task:
          state.fullGamePurchasedAt =
            self.apiClient.currentPlayer()?
            .appleReceipt?
            .receipt
            .originalPurchaseDate
          state.buildNumber = self.build.number()
          state.stats.isAnimationReduced = state.userSettings.enableReducedAnimation
          state.stats.isHapticsEnabled = state.userSettings.enableHaptics
          state.userSettings.appIcon = self.applicationClient.alternateIconName()
            .flatMap(AppIcon.init(rawValue:))

          if let baseUrl = DeveloperSettings.BaseUrl(
            rawValue: self.apiClient.baseUrl().absoluteString)
          {
            state.developer.currentBaseUrl = baseUrl
          }

          return .merge(
            .run { [shouldFetchProducts = !state.isFullGamePurchased] send in
              Task {
                await withTaskCancellation(id: CancelID.paymentObserver, cancelInFlight: true) {
                  for await event in self.storeKit.observer() {
                    await send(.paymentTransaction(event), animation: .default)
                  }
                }
              }

              async let productsResponse: Void =
                shouldFetchProducts
                ? send(
                  .productsResponse(
                    TaskResult {
                      try await self.storeKit.fetchProducts([
                        self.serverConfig().productIdentifiers.fullGame
                      ])
                    }
                  ),
                  animation: .default
                )
                : ()

              async let settingsResponse: Void = send(
                .userNotificationSettingsResponse(
                  self.userNotifications.getNotificationSettings()
                ),
                animation: .default
              )

              _ = await (productsResponse, settingsResponse)
            },

            .publisher {
              NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
                .map { _ in .didBecomeActive }
            }
          )

        case let .userNotificationAuthorizationResponse(.success(granted)):
          state.enableNotifications = granted
          return granted
            ? .run { _ in await self.registerForRemoteNotifications() }
            : .none

        case .userNotificationAuthorizationResponse:
          return .none

        case let .userNotificationSettingsResponse(settings):
          state.userNotificationSettings = settings
          state.enableNotifications = settings.authorizationStatus == .authorized
          return .none
        }
      }
    }
    .onChange(of: \.userSettings) { userSettings, _, _ in
      enum SaveDebounceID {}

      return .run { _ in try await self.fileClient.save(userSettings: userSettings) }
        .debounce(id: SaveDebounceID.self, for: .seconds(1), scheduler: self.mainQueue)
    }

    Scope(state: \.stats, action: /Action.stats) {
      Stats()
    }
  }
}

extension AlertState where Action == Settings.Action {
  static let userNotificationAuthorizationDenied = Self(
    title: .init("Permission Denied"),
    message: .init("Turn on notifications in iOS settings."),
    primaryButton: .default(.init("Ok"), action: .send(.set(\.$alert, nil))),
    secondaryButton: .default(.init("Open Settings"), action: .send(.openSettingButtonTapped))
  )

  static let restoredPurchasesFailed = Self(
    title: .init("Error"),
    message: .init("We couldn’t restore purchases, please try again."),
    dismissButton: .default(.init("Ok"), action: .send(.set(\.$alert, nil)))
  )

  static let noRestoredPurchases = Self(
    title: .init("No Purchases"),
    message: .init("No purchases were found to restore."),
    dismissButton: .default(.init("Ok"), action: .send(.set(\.$alert, nil)))
  )
}
