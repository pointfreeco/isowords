import ClientModels
import ComposableArchitecture
import ComposableGameCenter
import ComposableStoreKit
import ComposableUserNotifications
import CubeCore
import GameFeature
import HomeFeature
import OnboardingFeature
import ServerConfig
import ServerRouter
import SettingsFeature
import SharedModels
import Styleguide
import SwiftUI
import SwiftUIHelpers

public struct AppState: Equatable {
  public var game: GameState?
  public var onboarding: OnboardingState?
  public var home: HomeState

  public init(
    game: GameState? = nil,
    home: HomeState = .init(),
    onboarding: OnboardingState? = nil
  ) {
    self.game = game
    self.home = home
    self.onboarding = onboarding
  }

  public var currentGame: GameFeatureState {
    get {
      GameFeatureState(game: self.game, settings: self.home.settings)
    }
    set {
      let oldValue = self
      let isGameLoaded =
        newValue.game?.isGameLoaded == .some(true) || oldValue.game?.isGameLoaded == .some(true)
      let activeGames =
        newValue.game?.activeGames.isEmpty == .some(false)
        ? newValue.game?.activeGames
        : oldValue.game?.activeGames
      self.game = newValue.game
      self.game?.activeGames = activeGames ?? .init()
      self.game?.isGameLoaded = isGameLoaded
      self.home.settings = newValue.settings
    }
  }

  var isGameInActive: Bool {
    self.game == nil
  }

  var firstLaunchOnboarding: OnboardingState? {
    switch self.onboarding?.presentationStyle {
    case .some(.demo), .some(.help), .none:
      return nil

    case .some(.firstLaunch):
      return self.onboarding
    }
  }
}

public enum AppAction: Equatable {
  case appDelegate(AppDelegateAction)
  case currentGame(GameFeatureAction)
  case didChangeScenePhase(ScenePhase)
  case gameCenter(GameCenterAction)
  case home(HomeAction)
  case onboarding(OnboardingAction)
  case paymentTransaction(StoreKitClient.PaymentTransactionObserverEvent)
  case savedGamesLoaded(Result<SavedGamesState, NSError>)
  case verifyReceiptResponse(Result<ReceiptFinalizationEnvelope, NSError>)
}

extension AppEnvironment {
  var game: GameEnvironment {
    .init(
      apiClient: self.apiClient,
      applicationClient: self.applicationClient,
      audioPlayer: self.audioPlayer,
      backgroundQueue: self.backgroundQueue,
      build: self.build,
      database: self.database,
      dictionary: self.dictionary,
      feedbackGenerator: self.feedbackGenerator,
      fileClient: self.fileClient,
      gameCenter: self.gameCenter,
      lowPowerMode: self.lowPowerMode,
      mainQueue: self.mainQueue,
      mainRunLoop: self.mainRunLoop,
      remoteNotifications: self.remoteNotifications,
      serverConfig: self.serverConfig,
      setUserInterfaceStyle: self.setUserInterfaceStyle,
      storeKit: self.storeKit,
      userDefaults: self.userDefaults,
      userNotifications: self.userNotifications
    )
  }

  var home: HomeEnvironment {
    .init(
      apiClient: self.apiClient,
      applicationClient: self.applicationClient,
      audioPlayer: self.audioPlayer,
      backgroundQueue: self.backgroundQueue,
      build: self.build,
      database: self.database,
      deviceId: self.deviceId,
      feedbackGenerator: self.feedbackGenerator,
      fileClient: self.fileClient,
      gameCenter: self.gameCenter,
      lowPowerMode: self.lowPowerMode,
      mainQueue: self.mainQueue,
      mainRunLoop: self.mainRunLoop,
      remoteNotifications: self.remoteNotifications,
      serverConfig: self.serverConfig,
      setUserInterfaceStyle: self.setUserInterfaceStyle,
      storeKit: self.storeKit,
      timeZone: self.timeZone,
      userDefaults: self.userDefaults,
      userNotifications: self.userNotifications
    )
  }
}

public let appReducer = Reducer<AppState, AppAction, AppEnvironment>.combine(
  appDelegateReducer
    .pullback(
      state: \.home.settings.userSettings,
      action: /AppAction.appDelegate,
      environment: {
        .init(
          apiClient: $0.apiClient,
          audioPlayer: $0.audioPlayer,
          backgroundQueue: $0.backgroundQueue,
          build: $0.build,
          dictionary: $0.dictionary,
          mainQueue: $0.mainQueue,
          remoteNotifications: $0.remoteNotifications,
          userNotifications: $0.userNotifications
        )
      }
    ),

  gameFeatureReducer
    .pullback(
      state: \AppState.currentGame,
      action: /AppAction.currentGame,
      environment: \.game
    ),

  homeReducer
    .pullback(
      state: \AppState.home,
      action: /AppAction.home,
      environment: \.home
    ),

  onboardingReducer
    .optional()
    .pullback(
      state: \.onboarding,
      action: /AppAction.onboarding,
      environment: {
        OnboardingEnvironment(
          audioPlayer: $0.audioPlayer,
          backgroundQueue: $0.backgroundQueue,
          dictionary: $0.dictionary,
          feedbackGenerator: $0.feedbackGenerator,
          lowPowerMode: $0.lowPowerMode,
          mainQueue: $0.mainQueue,
          mainRunLoop: $0.mainRunLoop,
          userDefaults: $0.userDefaults
        )
      }),

  appReducerCore
)
.gameCenter()
.storeKit()
.persistence()

extension Reducer where State == AppState, Action == AppAction, Environment == AppEnvironment {
  func persistence() -> Self {
    self
      .onChange(of: \.game?.moves) { moves, state, _, environment in
        guard let game = state.game, game.isSavable
        else { return .none }

        switch (game.gameContext, game.gameMode) {
        case (.dailyChallenge, .unlimited):
          state.home.savedGames.dailyChallengeUnlimited = InProgressGame(gameState: game)
        case (.shared, .unlimited), (.solo, .unlimited):
          state.home.savedGames.unlimited = InProgressGame(gameState: game)
        case (.turnBased, _), (_, .timed):
          return .none
        }
        return .none
      }
      .onChange(of: \.home.savedGames) { savedGames, _, action, environment in
        if case .savedGamesLoaded(.success) = action { return .none }
        return environment.fileClient
          .saveGames(games: savedGames, on: environment.backgroundQueue)
          .fireAndForget()
      }
  }
}

let appReducerCore = Reducer<AppState, AppAction, AppEnvironment> { state, action, environment in
  switch action {
  case .appDelegate(.didFinishLaunching):
    if !environment.userDefaults.hasShownFirstLaunchOnboarding {
      state.onboarding = .init(presentationStyle: .firstLaunch)
    }

    return .merge(
      environment.database.migrate
        .fireAndForget(),

      environment.fileClient.loadSavedGames().map(AppAction.savedGamesLoaded),

      environment.userDefaults.installationTime <= 0
        ? environment.userDefaults.setInstallationTime(
          environment.mainRunLoop.now.date.timeIntervalSinceReferenceDate
        )
        .fireAndForget()
        : .none
    )

  case let .appDelegate(.userNotifications(.didReceiveResponse(response, completionHandler))):
    let effect = Effect<AppAction, Never>.fireAndForget(completionHandler)

    guard
      let data =
        try? JSONSerialization
        .data(withJSONObject: response.notification.request.content.userInfo),
      let pushNotificationContent = try? JSONDecoder()
        .decode(PushNotificationContent.self, from: data)
    else { return effect }

    switch pushNotificationContent {
    case .dailyChallengeEndsSoon:
      if let inProgressGame = state.home.savedGames.dailyChallengeUnlimited {
        state.currentGame = GameFeatureState(
          game: GameState(inProgressGame: inProgressGame),
          settings: state.home.settings
        )
      } else {
        // TODO: load/retry
      }

    case .dailyChallengeReport:
      state.game = nil
      state.home.route = .dailyChallenge(.init())
    }

    return effect

  case .appDelegate:
    return .none

  case .currentGame(.game(.endGameButtonTapped)),
    .currentGame(.game(.gameOver(.onAppear))):

    guard let game = state.game, game.gameMode == .unlimited
    else { return .none }

    if game.isDailyChallenge {
      state.home.savedGames.dailyChallengeUnlimited = nil
    } else {
      state.home.savedGames.unlimited = nil
    }
    return .none

  case .currentGame(.game(.activeGames(.dailyChallengeTapped))),
    .home(.activeGames(.dailyChallengeTapped)):
    guard let inProgressGame = state.home.savedGames.dailyChallengeUnlimited
    else { return .none }

    state.currentGame = .init(
      game: GameState(inProgressGame: inProgressGame),
      settings: state.home.settings
    )
    return .none

  case .currentGame(.game(.activeGames(.soloTapped))),
    .home(.activeGames(.soloTapped)):
    guard let inProgressGame = state.home.savedGames.unlimited
    else { return .none }

    state.currentGame = .init(
      game: GameState(inProgressGame: inProgressGame),
      settings: state.home.settings
    )
    return .none

  case let .currentGame(.game(.activeGames(.turnBasedGameTapped(matchId)))),
    let .home(.activeGames(.turnBasedGameTapped(matchId))):
    return environment.gameCenter.turnBasedMatch.load(matchId)
      .ignoreFailure()
      .map {
        .gameCenter(
          .listener(
            .turnBased(
              .receivedTurnEventForMatch($0, didBecomeActive: true)
            )
          )
        )
      }
      .receive(on: environment.mainQueue.animation())
      .eraseToEffect()

  case .currentGame(.game(.exitButtonTapped)),
    .currentGame(.game(.gameOver(.delegate(.close)))):
    state.game = nil
    return .none

  case .currentGame(.game(.gameOver(.delegate(.startSoloGame(.timed))))),
    .home(.solo(.gameButtonTapped(.timed))):
    state.game = .init(
      cubes: environment.dictionary.randomCubes(.en),
      gameContext: .solo,
      gameCurrentTime: environment.mainRunLoop.now.date,
      gameMode: .timed,
      gameStartTime: environment.mainRunLoop.now.date,
      isGameLoaded: state.currentGame.game?.isGameLoaded == .some(true)
    )
    return .none

  case .currentGame(.game(.gameOver(.delegate(.startSoloGame(.unlimited))))),
    .home(.solo(.gameButtonTapped(.unlimited))):
    state.game =
      state.home.savedGames.unlimited
      .map { GameState(inProgressGame: $0) }
      ?? GameState(
        cubes: environment.dictionary.randomCubes(.en),
        gameContext: .solo,
        gameCurrentTime: environment.mainRunLoop.now.date,
        gameMode: .unlimited,
        gameStartTime: environment.mainRunLoop.now.date,
        isGameLoaded: state.currentGame.game?.isGameLoaded == .some(true)
      )
    return .none

  case .currentGame:
    return .none

  case let .home(.dailyChallenge(.delegate(.startGame(inProgressGame)))):
    state.game = .init(inProgressGame: inProgressGame)
    return .none

  case let .home(.dailyChallengeResponse(.success(dailyChallenges))):
    if dailyChallenges.unlimited?.dailyChallenge.id
      != state.home.savedGames.dailyChallengeUnlimited?.dailyChallengeId
    {
      state.home.savedGames.dailyChallengeUnlimited = nil
      return environment.fileClient
        .saveGames(games: state.home.savedGames, on: environment.backgroundQueue)
        .fireAndForget()
    }
    return .none

  case .home(.howToPlayButtonTapped):
    state.onboarding = .init(presentationStyle: .help)
    return .none

  case .didChangeScenePhase(.active):
    return .merge(
      Effect.registerForRemoteNotifications(
        mainQueue: environment.mainQueue,
        remoteNotifications: environment.remoteNotifications,
        userNotifications: environment.userNotifications
      )
      .fireAndForget(),

      environment.serverConfig.refresh()
        .fireAndForget()
    )

  case .didChangeScenePhase:
    return .none

  case .gameCenter:
    return .none

  case .home:
    return .none

  case let .onboarding(.delegate(action)):
    switch action {
    case .getStarted:
      state.onboarding = nil
      return .none
    }

  case .onboarding:
    return .none

  case .paymentTransaction:
    return .none

  case .savedGamesLoaded(.failure):
    return .none

  case let .savedGamesLoaded(.success(savedGames)):
    state.home.savedGames = savedGames
    return .none

  case .verifyReceiptResponse:
    return .none
  }
}

public struct AppView: View {
  let store: Store<AppState, AppAction>

  public init(store: Store<AppState, AppAction>) {
    self.store = store
  }

  public var body: some View {
    IfLetStore(
      self.store.scope(
        state: \.firstLaunchOnboarding,
        action: AppAction.onboarding
      ),
      then: { store in
        OnboardingView(store: store)
      },
      else: MainAppView(store: self.store)
    )
    .modifier(DeviceStateModifier())
  }
}

public struct MainAppView: View {
  let store: Store<AppState, AppAction>
  @ObservedObject var viewStore: ViewStore<ViewState, AppAction>
  @Environment(\.deviceState) var deviceState

  struct ViewState: Equatable {
    let isGameActive: Bool
    let isOnboardingPresented: Bool

    init(state: AppState) {
      self.isGameActive = state.game != nil
      self.isOnboardingPresented = state.onboarding?.presentationStyle == .help
    }
  }

  public init(store: Store<AppState, AppAction>) {
    self.store = store
    self.viewStore = ViewStore(self.store.scope(state: ViewState.init))
  }

  public var body: some View {
    if !self.viewStore.isOnboardingPresented && !self.viewStore.isGameActive {
      NavigationView {
        HomeView(store: self.store.scope(state: \.home, action: AppAction.home))
      }
      .navigationViewStyle(StackNavigationViewStyle())
      .zIndex(0)
    } else {
      IfLetStore(
        self.store.scope(
          state: { appState in
            appState.game.map {
              (
                game: $0,
                nub: nil,
                settings: .init(
                  enableCubeShadow: appState.home.settings.enableCubeShadow,
                  enableGyroMotion: appState.home.settings.userSettings.enableGyroMotion,
                  showSceneStatistics: appState.home.settings.showSceneStatistics
                )
              )
            }
          }
        ),
        then: { gameAndSettingsStore in
          GameFeatureView(
            content: CubeView(
              store: gameAndSettingsStore.scope(
                state: CubeSceneView.ViewState.init(game:nub:settings:),
                action: { .currentGame(.game(CubeSceneView.ViewAction.to(gameAction: $0))) }
              )
            ),
            store: self.store.scope(state: \.currentGame, action: AppAction.currentGame)
          )
        }
      )
      .transition(.game)
      .zIndex(1)

      IfLetStore(
        self.store.scope(state: \.onboarding, action: AppAction.onboarding),
        then: OnboardingView.init(store:)
      )
      .zIndex(2)
    }
  }
}

#if DEBUG
  struct AppView_Previews: PreviewProvider {
    static var previews: some View {
      AppView(
        store: .init(
          initialState: .init(),
          reducer: appReducer,
          environment: .noop
        )
      )
    }
  }
#endif
