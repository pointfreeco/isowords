import ActiveGamesFeature
import ApiClient
import AudioPlayerClient
import Build
import ClientModels
import Combine
import CombineHelpers
import ComposableArchitecture
import ComposableGameCenter
import ComposableGameCenterHelpers
import ComposableStoreKit
import ComposableUserNotifications
import DailyChallengeFeature
import DeviceId
import FeedbackGeneratorClient
import FileClient
import GameKit
import LeaderboardFeature
import LocalDatabaseClient
import LowPowerModeClient
import MultiplayerFeature
import Overture
import RemoteNotificationsClient
import ServerConfigClient
import SettingsFeature
import SharedModels
import SoloFeature
import Styleguide
import SwiftUI
import UIApplicationClient
import UpgradeInterstitialFeature
import UserDefaultsClient

public enum AppRoute: Equatable {
  case dailyChallenge(DailyChallengeState)
  case leaderboard(LeaderboardState)
  case multiplayer(MultiplayerState)
  case settings
  case solo(SoloState)

  public enum Tag: Int {
    case dailyChallenge
    case leaderboard
    case multiplayer
    case settings
    case solo
  }

  var tag: Tag {
    switch self {
    case .dailyChallenge:
      return .dailyChallenge
    case .leaderboard:
      return .leaderboard
    case .multiplayer:
      return .multiplayer
    case .settings:
      return .settings
    case .solo:
      return .solo
    }
  }
}

public struct HomeState: Equatable {
  public var dailyChallenges: [FetchTodaysDailyChallengeResponse]?
  public var hasPastTurnBasedGames: Bool
  public var nagBanner: NagBannerState?
  public var route: AppRoute?
  public var savedGames: SavedGamesState {
    didSet {
      guard case var .dailyChallenge(dailyChallengeState) = self.route
      else { return }
      dailyChallengeState.inProgressDailyChallengeUnlimited =
        self.savedGames.dailyChallengeUnlimited
      self.route = .dailyChallenge(dailyChallengeState)
    }
  }
  public var settings: SettingsState
  public var turnBasedMatches: [ActiveTurnBasedMatch]
  public var weekInReview: FetchWeekInReviewResponse?

  public var activeGames: ActiveGamesState {
    get {
      .init(
        savedGames: self.savedGames,
        turnBasedMatches: self.turnBasedMatches
      )
    }
    set {
      self.savedGames = newValue.savedGames
      self.turnBasedMatches = newValue.turnBasedMatches
    }
  }

  public init(
    dailyChallenges: [FetchTodaysDailyChallengeResponse]? = nil,
    hasPastTurnBasedGames: Bool = false,
    nagBanner: NagBannerState? = nil,
    route: AppRoute? = nil,
    savedGames: SavedGamesState = SavedGamesState(),
    settings: SettingsState = SettingsState(),
    turnBasedMatches: [ActiveTurnBasedMatch] = [],
    weekInReview: FetchWeekInReviewResponse? = nil
  ) {
    self.dailyChallenges = dailyChallenges
    self.hasPastTurnBasedGames = hasPastTurnBasedGames
    self.nagBanner = nagBanner
    self.route = route
    self.savedGames = savedGames
    self.settings = settings
    self.turnBasedMatches = turnBasedMatches
    self.weekInReview = weekInReview
  }
}

public enum HomeAction: Equatable {
  case activeGames(ActiveGamesAction)
  case authenticationResponse(CurrentPlayerEnvelope)
  case binding(BindingAction<HomeState>)
  case dailyChallenge(DailyChallengeAction)
  case dailyChallengeResponse(Result<[FetchTodaysDailyChallengeResponse], ApiError>)
  case gameButtonTapped(GameButtonAction)
  case howToPlayButtonTapped
  case leaderboard(LeaderboardAction)
  case matchesLoaded(Result<[ActiveTurnBasedMatch], NSError>)
  case multiplayer(MultiplayerAction)
  case nagBannerFeature(NagBannerFeatureAction)
  case onAppear
  case onDisappear
  case savedGamesLoaded(Result<SavedGamesState, NSError>)
  case setNavigation(tag: AppRoute.Tag?)
  case settings(SettingsAction)
  case solo(SoloAction)
  case weekInReviewResponse(Result<FetchWeekInReviewResponse, ApiError>)

  public enum GameButtonAction: Equatable {
    case dailyChallenge
    case multiplayer
    case solo
  }
}

public struct HomeEnvironment {
  public var apiClient: ApiClient
  public var applicationClient: UIApplicationClient
  public var audioPlayer: AudioPlayerClient
  public var backgroundQueue: AnySchedulerOf<DispatchQueue>
  public var build: Build
  public var database: LocalDatabaseClient
  public var deviceId: DeviceIdentifier
  public var feedbackGenerator: FeedbackGeneratorClient
  public var fileClient: FileClient
  public var gameCenter: GameCenterClient
  public var lowPowerMode: LowPowerModeClient
  public var mainQueue: AnySchedulerOf<DispatchQueue>
  public var mainRunLoop: AnySchedulerOf<RunLoop>
  public var remoteNotifications: RemoteNotificationsClient
  public var serverConfig: ServerConfigClient
  public var setUserInterfaceStyle: (UIUserInterfaceStyle) -> Effect<Never, Never>
  public var storeKit: StoreKitClient
  public var timeZone: () -> TimeZone
  public var userDefaults: UserDefaultsClient
  public var userNotifications: UserNotificationClient

  public init(
    apiClient: ApiClient,
    applicationClient: UIApplicationClient,
    audioPlayer: AudioPlayerClient,
    backgroundQueue: AnySchedulerOf<DispatchQueue>,
    build: Build,
    database: LocalDatabaseClient,
    deviceId: DeviceIdentifier,
    feedbackGenerator: FeedbackGeneratorClient,
    fileClient: FileClient,
    gameCenter: GameCenterClient,
    lowPowerMode: LowPowerModeClient,
    mainQueue: AnySchedulerOf<DispatchQueue>,
    mainRunLoop: AnySchedulerOf<RunLoop>,
    remoteNotifications: RemoteNotificationsClient,
    serverConfig: ServerConfigClient,
    setUserInterfaceStyle: @escaping (UIUserInterfaceStyle) -> Effect<Never, Never>,
    storeKit: StoreKitClient,
    timeZone: @escaping () -> TimeZone,
    userDefaults: UserDefaultsClient,
    userNotifications: UserNotificationClient
  ) {
    self.apiClient = apiClient
    self.applicationClient = applicationClient
    self.audioPlayer = audioPlayer
    self.backgroundQueue = backgroundQueue
    self.build = build
    self.database = database
    self.deviceId = deviceId
    self.feedbackGenerator = feedbackGenerator
    self.fileClient = fileClient
    self.gameCenter = gameCenter
    self.lowPowerMode = lowPowerMode
    self.mainQueue = mainQueue
    self.mainRunLoop = mainRunLoop
    self.remoteNotifications = remoteNotifications
    self.serverConfig = serverConfig
    self.setUserInterfaceStyle = setUserInterfaceStyle
    self.storeKit = storeKit
    self.timeZone = timeZone
    self.userDefaults = userDefaults
    self.userNotifications = userNotifications
  }
}

#if DEBUG
  extension HomeEnvironment {
    public static let noop = Self(
      apiClient: .noop,
      applicationClient: .noop,
      audioPlayer: .noop,
      backgroundQueue: .immediate,
      build: .noop,
      database: .noop,
      deviceId: .noop,
      feedbackGenerator: .noop,
      fileClient: .noop,
      gameCenter: .noop,
      lowPowerMode: .false,
      mainQueue: .immediate,
      mainRunLoop: .immediate,
      remoteNotifications: .noop,
      serverConfig: .noop,
      setUserInterfaceStyle: { _ in .none },
      storeKit: .noop,
      timeZone: { TimeZone(secondsFromGMT: 0)! },
      userDefaults: .noop,
      userNotifications: .noop
    )
  }
#endif

public let homeReducer = Reducer<HomeState, HomeAction, HomeEnvironment>.combine(
  dailyChallengeReducer
    ._pullback(
      state: (\HomeState.route).appending(path: /AppRoute.dailyChallenge),
      action: /HomeAction.dailyChallenge,
      environment: {
        .init(
          apiClient: $0.apiClient,
          fileClient: $0.fileClient,
          mainQueue: $0.mainQueue,
          mainRunLoop: $0.mainRunLoop,
          remoteNotifications: $0.remoteNotifications,
          userNotifications: $0.userNotifications
        )
      }
    ),

  leaderboardReducer
    ._pullback(
      state: (\HomeState.route).appending(path: /AppRoute.leaderboard),
      action: /HomeAction.leaderboard,
      environment: {
        .init(
          apiClient: $0.apiClient,
          audioPlayer: $0.audioPlayer,
          feedbackGenerator: $0.feedbackGenerator,
          lowPowerMode: $0.lowPowerMode,
          mainQueue: $0.mainQueue
        )
      }
    ),

  multiplayerReducer
    ._pullback(
      state: (\HomeState.route).appending(path: /AppRoute.multiplayer),
      action: /HomeAction.multiplayer,
      environment: {
        .init(
          backgroundQueue: $0.backgroundQueue,
          gameCenter: $0.gameCenter,
          mainQueue: $0.mainQueue
        )
      }
    ),

  nagBannerFeatureReducer
    .pullback(
      state: \HomeState.nagBanner,
      action: /HomeAction.nagBannerFeature,
      environment: {
        NagBannerEnvironment(
          mainRunLoop: $0.mainRunLoop,
          serverConfig: $0.serverConfig,
          storeKit: $0.storeKit
        )
      }
    ),

  settingsReducer
    .pullback(
      state: \HomeState.settings,
      action: /HomeAction.settings,
      environment: {
        SettingsEnvironment(
          apiClient: $0.apiClient,
          applicationClient: $0.applicationClient,
          audioPlayer: $0.audioPlayer,
          backgroundQueue: $0.backgroundQueue,
          build: $0.build,
          database: $0.database,
          feedbackGenerator: $0.feedbackGenerator,
          fileClient: $0.fileClient,
          lowPowerMode: $0.lowPowerMode,
          mainQueue: $0.mainQueue,
          remoteNotifications: $0.remoteNotifications,
          serverConfig: $0.serverConfig,
          setUserInterfaceStyle: $0.setUserInterfaceStyle,
          storeKit: $0.storeKit,
          userDefaults: $0.userDefaults,
          userNotifications: $0.userNotifications
        )
      }
    ),

  soloReducer
    ._pullback(
      state: (\HomeState.route).appending(path: /AppRoute.solo),
      action: /HomeAction.solo,
      environment: { .init(fileClient: $0.fileClient) }
    ),

  .init { state, action, environment in
    switch action {
    case let .activeGames(.turnBasedGameMenuItemTapped(.deleteMatch(matchId))):
      return .concatenate(
        environment.gameCenter.turnBasedMatch.load(matchId)
          .flatMap { match in
            forceQuitMatch(match: match, gameCenter: environment.gameCenter)
          }
          .fireAndForget(),

        loadMatches(
          gameCenter: environment.gameCenter,
          backgroundQueue: environment.backgroundQueue,
          mainRunLoop: environment.mainRunLoop
        )
      )

    case let .activeGames(.turnBasedGameMenuItemTapped(.rematch(matchId))):
      return .none

    case let .activeGames(.turnBasedGameMenuItemTapped(.sendReminder(matchId, otherPlayerIndex))):
      return environment.gameCenter.turnBasedMatch
        .sendReminder(
          .init(
            for: matchId,
            to: [otherPlayerIndex.rawValue],
            localizableMessageKey: "It's your turn now!",
            arguments: []
          )
        )
        .ignoreOutput()
        .ignoreFailure()
        .eraseToEffect()
        .fireAndForget()

    case .activeGames:
      return .none

    case let .authenticationResponse(currentPlayerEnvelope):
      state.settings.sendDailyChallengeReminder =
        currentPlayerEnvelope.player.sendDailyChallengeReminder
      state.settings.sendDailyChallengeSummary =
        currentPlayerEnvelope.player.sendDailyChallengeSummary
      return .none

    case .binding:
      return .none

    case .dailyChallenge:
      return .none

    case let .dailyChallengeResponse(.success(dailyChallenges)):
      state.dailyChallenges = dailyChallenges
      return .none

    case let .dailyChallengeResponse(.failure(error)):
      state.dailyChallenges = []
      return .none

    case .gameButtonTapped:
      return .none

    case .howToPlayButtonTapped:
      return .none

    case .leaderboard:
      return .none

    case .matchesLoaded(.failure):
      return .none

    case let .matchesLoaded(.success(matches)):
      state.turnBasedMatches = matches
      return .none

    case .multiplayer:
      return .none

    case .onDisappear:
      return .cancel(id: ListenerId())

    case .onAppear:
      let shouldNag =
        Int(
          environment.mainRunLoop.now.date.timeIntervalSinceReferenceDate
            - environment.userDefaults.installationTime)
        >= environment.serverConfig.config().upgradeInterstitial.nagBannerAfterInstallDuration
      let isFullGamePurchased =
        environment.apiClient.currentPlayer()?.appleReceipt?.receipt.originalPurchaseDate != nil

      state.nagBanner =
        !isFullGamePurchased && shouldNag
        ? .init()
        : nil

      return .merge(
        onAppearEffects(environment: environment),

        environment.gameCenter.localPlayer.listener
          .cancellable(id: ListenerId(), cancelInFlight: true)
          .filter {
            switch $0 {
            case .turnBased(.matchEnded),
              .turnBased(.receivedTurnEventForMatch):
              return true
            default:
              return false
            }
          }
          .flatMap { _ in
            loadMatches(
              gameCenter: environment.gameCenter,
              backgroundQueue: environment.backgroundQueue,
              mainRunLoop: environment.mainRunLoop
            )
          }
          .eraseToEffect()
      )

    case .savedGamesLoaded(.failure):
      return .none

    case let .savedGamesLoaded(.success(savedGames)):
      state.savedGames = savedGames
      return .none

    case let .setNavigation(tag: tag):
      switch tag {
      case .dailyChallenge:
        state.route = .dailyChallenge(
          .init(
            dailyChallenges: state.dailyChallenges ?? [],
            inProgressDailyChallengeUnlimited: state.savedGames.dailyChallengeUnlimited
          )
        )
      case .leaderboard:
        state.route = .leaderboard(
          .init(
            isAnimationReduced: state.settings.userSettings.enableReducedAnimation,
            isHapticsEnabled: state.settings.userSettings.enableHaptics,
            settings: .init(
              enableCubeShadow: state.settings.enableCubeShadow,
              enableGyroMotion: state.settings.userSettings.enableGyroMotion,
              showSceneStatistics: state.settings.showSceneStatistics
            )
          )
        )
      case .multiplayer:
        state.route = .multiplayer(.init(hasPastGames: state.hasPastTurnBasedGames))
      case .settings:
        state.route = .settings
      case .solo:
        state.route = .solo(.init(inProgressGame: state.savedGames.unlimited))
      case .none:
        state.route = .none
      }
      return .none

    case .nagBannerFeature:
      return .none

    case .settings:
      return .none

    case .solo:
      return .none

    case .weekInReviewResponse(.failure):
      return .none

    case let .weekInReviewResponse(.success(response)):
      state.weekInReview = response
      return .none
    }
  }
)
.binding(action: /HomeAction.binding)

public struct HomeView: View {
  struct ViewState: Equatable {
    let hasActiveGames: Bool
    var isNagBannerVisible: Bool
    let tag: AppRoute.Tag?

    init(state: HomeState) {
      self.hasActiveGames =
        state.savedGames.dailyChallengeUnlimited != nil
        || state.savedGames.unlimited != nil
        || !state.turnBasedMatches.isEmpty
      self.isNagBannerVisible = state.nagBanner != nil
      self.tag = state.route?.tag
    }
  }

  @Environment(\.colorScheme) var colorScheme
  let store: Store<HomeState, HomeAction>
  @ObservedObject var viewStore: ViewStore<ViewState, HomeAction>

  public init(store: Store<HomeState, HomeAction>) {
    self.store = store
    self.viewStore = ViewStore(store.scope(state: ViewState.init))
  }

  public var body: some View {
    ZStack(alignment: .bottom) {
      ScrollView {
        VStack(spacing: .grid(12)) {
          VStack(spacing: .grid(6)) {
            HStack {
              Image(systemName: "cube.fill")

              Spacer()

              Button(action: { self.viewStore.send(.howToPlayButtonTapped, animation: .default) }) {
                Image(systemName: "questionmark.circle")
              }

              NavigationLink(
                destination: SettingsView(
                  store: self.store.scope(
                    state: \.settings,
                    action: HomeAction.settings
                  ),
                  navPresentationStyle: .navigation
                ),
                tag: AppRoute.Tag.settings,
                selection: viewStore.binding(get: \.tag, send: HomeAction.setNavigation(tag:))
                  .animation()
              ) {
                Image(systemName: "gear")
              }
            }
            .font(.system(size: 24))
            .foregroundColor(self.colorScheme == .dark ? .hex(0xF2E29F) : .isowordsBlack)
            .adaptivePadding([.leading, .trailing])

            DailyChallengeHeaderView(store: self.store)
              .screenEdgePadding(.horizontal)
          }

          if self.viewStore.hasActiveGames {
            VStack(alignment: .leading) {
              Text("Active games")
                .adaptiveFont(.matterMedium, size: 16)
                .foregroundColor(self.colorScheme == .dark ? .hex(0xEBAE83) : .isowordsBlack)
                .screenEdgePadding(.horizontal)

              ActiveGamesView(
                store: self.store.scope(
                  state: \.activeGames,
                  action: HomeAction.activeGames
                ),
                showMenuItems: true
              )
              .foregroundColor(self.colorScheme == .dark ? .hex(0xE9A27C) : .isowordsBlack)
            }
          }

          StartNewGameView(store: self.store)
            .screenEdgePadding(.horizontal)
          LeaderboardLinkView(store: self.store)
            .screenEdgePadding(.horizontal)
        }
        .adaptivePadding([.top, .bottom], .grid(4))
        .background(
          self.colorScheme == .dark
            ? AnyView(Color.isowordsBlack)
            : AnyView(
              LinearGradient(
                gradient: Gradient(colors: [.hex(0xF3EBA4), .hex(0xE1665B)]),
                startPoint: .top,
                endPoint: .bottom
              )
            )
        )

        if self.viewStore.isNagBannerVisible {
          Spacer().frame(height: 80)
        }
      }
      .background(
        (self.colorScheme == .dark
          ? AnyView(Color.isowordsBlack)
          : AnyView(
            LinearGradient(
              gradient: Gradient(
                stops: [
                  .init(color: .hex(0xF3EBA4), location: 0),
                  .init(color: .hex(0xF3EBA4), location: 0.5),
                  .init(color: .hex(0xE1665B), location: 0.5),
                  .init(color: .hex(0xE1665B), location: 1),
                ]
              ),
              startPoint: .top,
              endPoint: .bottom
            )
          ))
          .ignoresSafeArea()
      )

      NagBannerFeature(
        store: self.store.scope(
          state: \.nagBanner,
          action: HomeAction.nagBannerFeature
        )
      )
    }
    .navigationBarHidden(true)
    .onAppear { self.viewStore.send(.onAppear) }
    .onDisappear { self.viewStore.send(.onDisappear) }
  }
}

extension HomeState {
  var hasActiveGames: Bool {
    self.savedGames.dailyChallengeUnlimited != nil
      || self.savedGames.unlimited != nil
      || !self.turnBasedMatches.isEmpty
  }
}

func onAppearEffects(environment: HomeEnvironment) -> Effect<HomeAction, Never> {
  var serverAuthentication: Effect<HomeAction, Never> {
    environment.apiClient.authenticate(
      .init(
        deviceId: .init(rawValue: environment.deviceId.id()),
        displayName: environment.gameCenter.localPlayer.localPlayer().isAuthenticated
          ? environment.gameCenter.localPlayer.localPlayer().displayName
          : nil,
        gameCenterLocalPlayerId: environment.gameCenter.localPlayer.localPlayer().isAuthenticated
          ? .init(rawValue: environment.gameCenter.localPlayer.localPlayer().gamePlayerId.rawValue)
          : nil,
        timeZone: environment.timeZone().identifier
      )
    )
    .ignoreFailure()
    .flatMap { envelope in
      Effect.concatenate(
        Effect(value: .authenticationResponse(envelope)),
        environment.serverConfig.refresh()
          .ignoreOutput()
          .ignoreFailure()
          .eraseToEffect()
          .fireAndForget()
      )
    }
    .eraseToEffect()
  }

  let serverAuthenticateAndLoadData = serverAuthentication.flatMap { authentication in
    Effect.merge(
      Effect(value: authentication),

      environment.apiClient
        .apiRequest(
          route: .dailyChallenge(.today(language: .en)),
          as: [FetchTodaysDailyChallengeResponse].self
        )
        .catchToEffect()
        .map(HomeAction.dailyChallengeResponse),

      environment.apiClient
        .apiRequest(
          route: .leaderboard(.weekInReview(language: .en)),
          as: FetchWeekInReviewResponse.self
        )
        .catchToEffect()
        .map(HomeAction.weekInReviewResponse)
    )
  }

  return
    environment.gameCenter.localPlayer.authenticate
    .flatMap { _ in
      Publishers.Merge(
        serverAuthenticateAndLoadData,

        loadMatches(
          gameCenter: environment.gameCenter,
          backgroundQueue: environment.backgroundQueue,
          mainRunLoop: environment.mainRunLoop
        )
      )
    }
    .receive(on: environment.mainQueue.animation())
    .eraseToEffect()
    .cancellable(id: AuthenticationId(), cancelInFlight: true)
}

private func loadMatches(
  gameCenter: GameCenterClient,
  backgroundQueue: AnySchedulerOf<DispatchQueue>,
  mainRunLoop: AnySchedulerOf<RunLoop>
) -> Effect<HomeAction, Never> {

  return gameCenter.turnBasedMatch.loadMatches()
    .receive(on: backgroundQueue)
    .mapError { $0 as NSError }
    .catchToEffect()
    .flatMap { result in
      Effect.merge(
        Effect(
          value: .binding(
            .set(
              \.hasPastTurnBasedGames,
              (try? result.get())?.contains { $0.status == .ended } == .some(true)
            )
          )
        )
        .receive(on: mainRunLoop)
        .eraseToEffect(),

        Effect(
          value: .matchesLoaded(
            result.map {
              $0.activeMatches(
                for: gameCenter.localPlayer.localPlayer(),
                at: mainRunLoop.now.date
              )
            }
          )
        )
        .receive(on: mainRunLoop.animation())
        .eraseToEffect()
      )
    }
    .eraseToEffect()
}

private struct ListenerId: Hashable {}
private struct AuthenticationId: Hashable {}

#if DEBUG
  @testable import ComposableGameCenter
  import SwiftUIHelpers

  struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
      Preview {
        NavigationView {
          HomeView(store: .home)
        }
      }
    }
  }

  extension Store where State == HomeState, Action == HomeAction {
    static let home = Store(
      initialState: update(.init()) {
        $0.dailyChallenges = [
          FetchTodaysDailyChallengeResponse(
            dailyChallenge: .init(
              endsAt: Date().addingTimeInterval(6 * 60 * 60),
              gameMode: .unlimited,
              id: .init(rawValue: UUID()),
              language: .en
            ),
            yourResult: .init(outOf: 0, rank: nil, score: nil)
          ),
          FetchTodaysDailyChallengeResponse(
            dailyChallenge: .init(
              endsAt: Date().addingTimeInterval(6 * 60 * 60),
              gameMode: .timed,
              id: .init(rawValue: UUID()),
              language: .en
            ),
            yourResult: .init(outOf: 0, rank: nil, score: nil)
          ),
        ]
        $0.savedGames = .init(
          dailyChallengeUnlimited: .init(
            cubes: .mock,
            gameContext: .dailyChallenge(.init(rawValue: .dailyChallengeId)),
            gameMode: .unlimited,
            gameStartTime: .mock,
            moves: [.highScoringMove],
            secondsPlayed: 0
          ),
          unlimited: .init(
            cubes: .mock,
            gameContext: .solo,
            gameMode: .unlimited,
            gameStartTime: .mock,
            moves: [.highScoringMove],
            secondsPlayed: 0
          )
        )
        $0.settings.fullGamePurchasedAt = .mock
        $0.turnBasedMatches = [
          .init(
            id: "1",
            isYourTurn: true,
            lastPlayedAt: .mock,
            now: .mock,
            playedWord: PlayedWord(
              isYourWord: false,
              reactions: [:],
              score: 120,
              word: "HELLO"
            ),
            status: .open,
            theirIndex: 1,
            theirName: "Blob"
          ),
          .init(
            id: "2",
            isYourTurn: false,
            lastPlayedAt: .mock,
            now: .mock,
            playedWord: PlayedWord(
              isYourWord: true,
              reactions: [:],
              score: 420,
              word: "GOODBYE"
            ),
            status: .open,
            theirIndex: 0,
            theirName: "Blob"
          ),
        ]
      },
      reducer: homeReducer,
      environment: HomeEnvironment(
        apiClient: .noop,
        applicationClient: .live,
        audioPlayer: .noop,
        backgroundQueue: DispatchQueue(label: "preview").eraseToAnyScheduler(),
        build: .noop,
        database: .noop,
        deviceId: .live,
        feedbackGenerator: .noop,
        fileClient: .noop,
        gameCenter: .noop,
        lowPowerMode: .false,
        mainQueue: .main,
        mainRunLoop: .main,
        remoteNotifications: .noop,
        serverConfig: .noop,
        setUserInterfaceStyle: { _ in .none },
        storeKit: .noop,
        timeZone: { .autoupdatingCurrent },
        userDefaults: .live(),
        userNotifications: .noop
      )
    )
  }
#endif
