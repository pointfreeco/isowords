import ApiClient
import AudioPlayerClient
import Build
import ComposableArchitecture
import ComposableStoreKit
import ComposableUserNotifications
import Dependencies
import RemoteNotificationsClient
import ServerConfigClient
import SharedModels
import StatsFeature
import StoreKit
import SwiftUI
import UIApplicationClient
import UserSettingsClient

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

    var url: URL { URL(string: rawValue)! }
  }
}

@Feature
public struct Settings {
  @Feature public enum Destination {
    case noRestoredPurchasesAlert
    case restoredPurchasesFailedAlert
    case userNotificationAuthorizationDeniedAlert(UserNotificationAuthorizationDeniedAlert)
  }

  @Feature public struct UserNotificationAuthorizationDeniedAlert: Prompt {
    public enum Action {
      case openSettingsButtonTapped
    }
  }

  public struct State {
    public var buildNumber: Build.Number?
    public var destination: Destination.State?
    public var developer: DeveloperSettings
    public var fullGameProduct: Result<StoreKitClient.Product, ProductError>?
    public var fullGamePurchasedAt: Date?
    public var isPurchasing: Bool
    public var isRestoring: Bool
    public var stats: Stats.State
    public var userNotificationSettings: UserNotificationClient.Notification.Settings?
    public var userSettings: UserSettings

    public struct ProductError: Error, Equatable {}

    public init(
      buildNumber: Build.Number? = nil,
      destination: Destination.State? = nil,
      developer: DeveloperSettings? = nil,
      fullGameProduct: Result<StoreKitClient.Product, ProductError>? = nil,
      fullGamePurchasedAt: Date? = nil,
      isPurchasing: Bool = false,
      isRestoring: Bool = false,
      stats: Stats.State = .init(),
      userNotificationSettings: UserNotificationClient.Notification.Settings? = nil
    ) {
      @Dependency(\.apiClient) var apiClient
      @Dependency(\.applicationClient) var applicationClient
      @Dependency(\.userSettings) var userSettings
      self.buildNumber = buildNumber
      self.destination = destination
      self.developer =
        developer
        ?? DeveloperSettings(
          currentBaseUrl: DeveloperSettings.BaseUrl(
            rawValue: apiClient.baseUrl().absoluteString
          ) ?? .production
        )
      self.fullGameProduct = fullGameProduct
      self.fullGamePurchasedAt = fullGamePurchasedAt
      self.isPurchasing = isPurchasing
      self.isRestoring = isRestoring
      self.stats = stats
      self.userNotificationSettings = userNotificationSettings
      self.userSettings = userSettings.get()

      let currentPlayer = apiClient.currentPlayer()
      self.stats.isAnimationReduced = self.userSettings.enableReducedAnimation
      self.userSettings.appIcon = applicationClient.alternateIconName()
        .flatMap(AppIcon.init(rawValue:))
      self.userSettings.sendDailyChallengeSummary =
        currentPlayer?.player.sendDailyChallengeSummary
        ?? self.userSettings.sendDailyChallengeSummary
      self.userSettings.sendDailyChallengeReminder =
        currentPlayer?.player.sendDailyChallengeReminder
        ?? self.userSettings.sendDailyChallengeReminder
    }

    public var isFullGamePurchased: Bool {
      fullGamePurchasedAt != nil
    }
  }

  public enum Action {
    case dailyChallengeReminderToggled(Bool)
    case dailyChallengeSummaryToggled(Bool)
    case destination(Destination.Action)
    case enableNotificationsToggled(Bool)
    case leaveUsAReviewButtonTapped
    case paymentTransaction(StoreKitClient.PaymentTransactionObserverEvent)
    case reportABugButtonTapped
    case restoreButtonTapped
    case stats(Stats.Action)
    case tappedProduct(StoreKitClient.Product)
  }

  @Dependency(\.apiClient) var apiClient
  @Dependency(\.applicationClient) var applicationClient
  @Dependency(\.audioPlayer) var audioPlayer
  @Dependency(\.build) var build
  @FeatureEnvironment(\.continuousClock) var clock
  @Dependency(\.remoteNotifications.register) var registerForRemoteNotifications
  @Dependency(\.serverConfig.config) var serverConfig
  @Dependency(\.storeKit) var storeKit
  @Dependency(\.userNotifications) var userNotifications
  @Dependency(\.userSettings) var userSettings

  @StoreTaskID var saveUserSettings

  public init() {}

  public var body: some Feature {
    Update { state, action in
      switch action {
      case let .dailyChallengeReminderToggled(sendDailyChallengeReminder):
        state.userSettings.sendDailyChallengeReminder = sendDailyChallengeReminder
        store.addTask {
          _ = try await apiClient.apiRequest(
            route: .push(
              .updateSetting(
                .init(
                  notificationType: .dailyChallengeEndsSoon,
                  sendNotifications: sendDailyChallengeReminder
                )
              )
            )
          )
          try await refreshCurrentPlayer(animated: false)
        }

      case let .dailyChallengeSummaryToggled(sendDailyChallengeSummary):
        state.userSettings.sendDailyChallengeSummary = sendDailyChallengeSummary
        store.addTask {
          _ = try await apiClient.apiRequest(
            route: .push(
              .updateSetting(
                .init(
                  notificationType: .dailyChallengeReport,
                  sendNotifications: sendDailyChallengeSummary
                )
              )
            )
          )
          try await refreshCurrentPlayer(animated: false)
        }

      case .destination(.userNotificationAuthorizationDeniedAlert(.openSettingsButtonTapped)):
        store.addTask {
          guard
            let url = await URL(string: applicationClient.openSettingsURLString())
          else { return }
          _ = await applicationClient.open(url, [:])
        }

      case let .enableNotificationsToggled(enableNotifications):
        state.userSettings.enableNotifications = enableNotifications
        guard
          enableNotifications,
          let userNotificationSettings = state.userNotificationSettings
        else {
          // TODO: API request to opt out of all notifications
          state.userSettings.enableNotifications = false
          return
        }

        switch userNotificationSettings.authorizationStatus {
        case .notDetermined, .provisional:
          state.userSettings.enableNotifications = true
          store.addTask {
            let granted = try await userNotifications.requestAuthorization([.alert, .sound])
            _ = try withAnimation {
              try store.modify { $0.userSettings.enableNotifications = granted }
            }
            if granted {
              await registerForRemoteNotifications()
            }
          }

        case .denied:
          state.destination = .userNotificationAuthorizationDeniedAlert(
            UserNotificationAuthorizationDeniedAlert.State()
          )
          state.userSettings.enableNotifications = false

        case .authorized:
          state.userSettings.enableNotifications = true
          store.addTask {
            await registerForRemoteNotifications()
          }

        case .ephemeral:
          state.userSettings.enableNotifications = true

        @unknown default:
          break
        }

      case .leaveUsAReviewButtonTapped:
        store.addTask {
          _ = await applicationClient
            .open(serverConfig().appStoreReviewUrl, [:])
        }

      case .paymentTransaction(.removedTransactions):
        state.isPurchasing = false
        store.addTask {
          try await refreshCurrentPlayer(animated: true)
        }

      case let .paymentTransaction(.restoreCompletedTransactionsFinished(transactions)):
        state.isRestoring = false
        state.destination = transactions.isEmpty ? .noRestoredPurchasesAlert : nil

      case .paymentTransaction(.restoreCompletedTransactionsFailed):
        state.isRestoring = false
        state.destination = .restoredPurchasesFailedAlert

      case let .paymentTransaction(.updatedTransactions(transactions)):
        if transactions.contains(where: { $0.error != nil }) {
          state.isPurchasing = false
        }

      case .reportABugButtonTapped:
        store.addTask {
          let currentPlayer = apiClient.currentPlayer()
          var components = URLComponents()
          components.scheme = "mailto"
          components.path = "support@pointfree.co"
          components.queryItems = [
            URLQueryItem(name: "subject", value: "I found a bug in isowords"),
            URLQueryItem(
              name: "body",
              value: """


                ---
                Build: \(build.number()) (\(build.gitSha()))
                \(currentPlayer?.player.id.rawValue.uuidString ?? "")
                """
            ),
          ]

          _ = await applicationClient.open(components.url!, [:])
        }

      case .restoreButtonTapped:
        state.isRestoring = true
        store.addTask { await storeKit.restoreCompletedTransactions() }

      case .stats:
        break

      case let .tappedProduct(product):
        state.isPurchasing = true
        store.addTask {
          let payment = SKMutablePayment()
          payment.productIdentifier = product.productIdentifier
          payment.quantity = 1
          await storeKit.addPayment(payment)
        }
      }
    }
    .ifLet(\.destination) {
      Destination.body
    }
    .onMount { state in
      state.fullGamePurchasedAt =
        apiClient.currentPlayer()?
        .appleReceipt?
        .receipt
        .originalPurchaseDate
      state.buildNumber = build.number()

      store.addTask {
        for await event in storeKit.observer() {
          _ = try withAnimation { try store.send(.paymentTransaction(event)) }
        }
      }

      if !state.isFullGamePurchased {
        store.addTask {
          let fullGameProduct: Result<StoreKitClient.Product, State.ProductError>
          do {
            let response = try await storeKit.fetchProducts([
              serverConfig().productIdentifiers.fullGame
            ])
            fullGameProduct =
              response.products
              .first { $0.productIdentifier == serverConfig().productIdentifiers.fullGame }
              .map(Result.success)
              ?? .failure(State.ProductError())
          } catch {
            fullGameProduct = .failure(State.ProductError())
          }
          _ = try withAnimation { try store.modify { $0.fullGameProduct = fullGameProduct } }
        }
      }

      store.addTask {
        try await refreshUserNotificationSettings(animated: true)
      }

      store.addTask {
        for await _ in NotificationCenter.default.notifications(
          named: UIApplication.didBecomeActiveNotification
        ) {
          try await refreshUserNotificationSettings(animated: false)
        }
      }
    }
    .onChange(of: store.developer.currentBaseUrl) { _, currentBaseUrl, _ in
      store.addTask {
        await apiClient.setBaseUrl(currentBaseUrl.url)
        await apiClient.logout()
      }
    }
    .onChange(of: store.userSettings.appIcon) { _, appIcon, _ in
      store.addTask {
        try await applicationClient.setAlternateIconName(appIcon?.rawValue)
      }
    }
    .onChange(of: store.userSettings.colorScheme) { _, colorScheme, _ in
      store.addTask {
        await applicationClient.setUserInterfaceStyle(colorScheme.userInterfaceStyle)
      }
    }
    .onChange(of: store.userSettings.musicVolume) { _, musicVolume, _ in
      store.addTask {
        await audioPlayer.setGlobalVolumeForMusic(musicVolume)
      }
    }
    .onChange(of: store.userSettings.soundEffectsVolume) { _, soundEffectsVolume, _ in
      store.addTask {
        await audioPlayer.setGlobalVolumeForSoundEffects(soundEffectsVolume)
      }
    }
    .onChange(of: store.userSettings) { _, userSettings, _ in
      store.addTask(id: saveUserSettings) {
        try await clock.sleep(for: .seconds(0.5))
        await self.userSettings.set(userSettings)
      }
    }

    Scope(\.stats) {
      Stats()
    }
  }

  private func refreshCurrentPlayer(animated: Bool) async throws {
    let envelope: CurrentPlayerEnvelope
    do {
      envelope = try await apiClient.refreshCurrentPlayer()
    } catch {
      try store.modify { $0.isRestoring = false }
      return
    }
    _ = try withAnimation(animated ? .default : nil) {
      try store.modify {
        $0.isRestoring = false
        $0.fullGamePurchasedAt = envelope.appleReceipt?.receipt.originalPurchaseDate
        $0.userSettings.sendDailyChallengeReminder = envelope.player.sendDailyChallengeReminder
        $0.userSettings.sendDailyChallengeSummary = envelope.player.sendDailyChallengeSummary
      }
    }
  }

  private func refreshUserNotificationSettings(animated: Bool) async throws {
    let settings = await userNotifications.getNotificationSettings()
    _ = try withAnimation(animated ? .default : nil) {
      try store.modify {
        $0.userNotificationSettings = settings
        // TODO: this is a bug, look into later
        $0.userSettings.enableNotifications = settings.authorizationStatus == .authorized
      }
    }
  }
}
