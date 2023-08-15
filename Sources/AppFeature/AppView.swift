import ClientModels
import ComposableArchitecture
import ComposableStoreKit
import CubeCore
import GameFeature
import HomeFeature
import NotificationHelpers
import OnboardingFeature
import SharedModels
import Styleguide
import SwiftUI

public struct AppReducer: ReducerProtocol {
  public struct State: Equatable {
    public var game: Game.State?
    public var onboarding: Onboarding.State?
    public var home: Home.State

    public init(
      game: Game.State? = nil,
      home: Home.State = .init(),
      onboarding: Onboarding.State? = nil
    ) {
      self.game = game
      self.home = home
      self.onboarding = onboarding
    }

    public var currentGame: GameFeature.State {
      get {
        GameFeature.State(game: self.game, settings: self.home.settings)
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

    var firstLaunchOnboarding: Onboarding.State? {
      switch self.onboarding?.presentationStyle {
      case .some(.demo), .some(.help), .none:
        return nil

      case .some(.firstLaunch):
        return self.onboarding
      }
    }
  }

  public enum Action: Equatable {
    case appDelegate(AppDelegateReducer.Action)
    case currentGame(GameFeature.Action)
    case didChangeScenePhase(ScenePhase)
    case gameCenter(GameCenterAction)
    case home(Home.Action)
    case onboarding(Onboarding.Action)
    case paymentTransaction(StoreKitClient.PaymentTransactionObserverEvent)
    case savedGamesLoaded(TaskResult<SavedGamesState>)
    case verifyReceiptResponse(TaskResult<ReceiptFinalizationEnvelope>)
  }

  @Dependency(\.fileClient) var fileClient
  @Dependency(\.gameCenter.turnBasedMatch.load) var loadTurnBasedMatch
  @Dependency(\.database.migrate) var migrate
  @Dependency(\.mainRunLoop.now.date) var now
  @Dependency(\.dictionary.randomCubes) var randomCubes
  @Dependency(\.remoteNotifications) var remoteNotifications
  @Dependency(\.serverConfig.refresh) var refreshServerConfig
  @Dependency(\.userDefaults) var userDefaults
  @Dependency(\.userNotifications) var userNotifications

  public init() {}

  public var body: some ReducerProtocol<State, Action> {
    self.core
      .ifLet(\.onboarding, action: /Action.onboarding) {
        Onboarding()
      }
      .onChange(of: \.game?.moves) { moves, state, _ in
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
      .onChange(of: \.home.savedGames) { savedGames, _, action in
        if case .savedGamesLoaded(.success) = action { return .none }
        return .run { _ in 
          try await self.fileClient.save(games: savedGames)
        }
      }

    GameCenterLogic()
    StoreKitLogic()
  }

  @ReducerBuilder<State, Action>
  var core: some ReducerProtocol<State, Action> {
    Scope(state: \.home.settings.userSettings, action: /Action.appDelegate) {
      AppDelegateReducer()
    }
    Scope(state: \.currentGame, action: /Action.currentGame) {
      GameFeature()
    }
    Scope(state: \.home, action: /Action.home) {
      Home()
    }
    Reduce { state, action in
      switch action {
      case .appDelegate(.didFinishLaunching):
        if !self.userDefaults.hasShownFirstLaunchOnboarding {
          state.onboarding = .init(presentationStyle: .firstLaunch)
        }

        return .run { send in
          async let migrate: Void = self.migrate()
          if self.userDefaults.installationTime <= 0 {
            await self.userDefaults.setInstallationTime(
              self.now.timeIntervalSinceReferenceDate
            )
          }
          await send(
            .savedGamesLoaded(
              TaskResult { try await self.fileClient.loadSavedGames() }
            )
          )
          _ = try await migrate
        }

      case let .appDelegate(.userNotifications(.didReceiveResponse(response, completionHandler))):
        if let data =
          try? JSONSerialization
          .data(withJSONObject: response.notification.request.content.userInfo),
          let pushNotificationContent = try? JSONDecoder()
            .decode(PushNotificationContent.self, from: data)
        {
          switch pushNotificationContent {
          case .dailyChallengeEndsSoon:
            if let inProgressGame = state.home.savedGames.dailyChallengeUnlimited {
              state.currentGame = GameFeature.State(
                game: Game.State(inProgressGame: inProgressGame),
                settings: state.home.settings
              )
            } else {
              // TODO: load/retry
            }

          case .dailyChallengeReport:
            state.game = nil
            state.home.destination = .dailyChallenge(.init())
          }
        }

        return .run { _ in completionHandler() }

      case .appDelegate:
        return .none

      case .currentGame(.game(.endGameButtonTapped)),
        .currentGame(.game(.gameOver(.task))):

        switch (state.game?.gameContext, state.game?.gameMode) {
        case (.dailyChallenge, .unlimited):
          state.home.savedGames.dailyChallengeUnlimited = nil
        case (.solo, .unlimited):
          state.home.savedGames.unlimited = nil
        default:
          break
        }
        return .none

      case .currentGame(.game(.activeGames(.dailyChallengeTapped))),
        .home(.activeGames(.dailyChallengeTapped)):
        guard let inProgressGame = state.home.savedGames.dailyChallengeUnlimited
        else { return .none }

        state.currentGame = .init(
          game: Game.State(inProgressGame: inProgressGame),
          settings: state.home.settings
        )
        return .none

      case .currentGame(.game(.activeGames(.soloTapped))),
        .home(.activeGames(.soloTapped)):
        guard let inProgressGame = state.home.savedGames.unlimited
        else { return .none }

        state.currentGame = .init(
          game: Game.State(inProgressGame: inProgressGame),
          settings: state.home.settings
        )
        return .none

      case let .currentGame(.game(.activeGames(.turnBasedGameTapped(matchId)))),
        let .home(.activeGames(.turnBasedGameTapped(matchId))):
        return .run { send in
          do {
            let match = try await self.loadTurnBasedMatch(matchId)
            await send(
              .gameCenter(
                .listener(.turnBased(.receivedTurnEventForMatch(match, didBecomeActive: true)))
              ),
              animation: .default
            )
          } catch {}
        }

      case .currentGame(.game(.exitButtonTapped)),
        .currentGame(.game(.gameOver(.delegate(.close)))):
        state.game = nil
        return .none

      case .currentGame(.game(.gameOver(.delegate(.startSoloGame(.timed))))),
        .home(.destination(.solo(.gameButtonTapped(.timed)))):
        state.game = .init(
          cubes: self.randomCubes(.en),
          gameContext: .solo,
          gameCurrentTime: self.now,
          gameMode: .timed,
          gameStartTime: self.now,
          isGameLoaded: state.currentGame.game?.isGameLoaded == .some(true)
        )
        return .none

      case .currentGame(.game(.gameOver(.delegate(.startSoloGame(.unlimited))))),
        .home(.destination(.solo(.gameButtonTapped(.unlimited)))):
        state.game =
          state.home.savedGames.unlimited
          .map { Game.State(inProgressGame: $0) }
          ?? Game.State(
            cubes: self.randomCubes(.en),
            gameContext: .solo,
            gameCurrentTime: self.now,
            gameMode: .unlimited,
            gameStartTime: self.now,
            isGameLoaded: state.currentGame.game?.isGameLoaded == .some(true)
          )
        return .none

      case .currentGame:
        return .none

      case let .home(.destination(.dailyChallenge(.delegate(.startGame(inProgressGame))))):
        state.game = .init(inProgressGame: inProgressGame)
        return .none

      case let .home(.dailyChallengeResponse(.success(dailyChallenges))):
        if dailyChallenges.unlimited?.dailyChallenge.id
          != state.home.savedGames.dailyChallengeUnlimited?.dailyChallengeId
        {
          state.home.savedGames.dailyChallengeUnlimited = nil
          return .run { [savedGames = state.home.savedGames] _ in
            try await self.fileClient.save(games: savedGames)
          }
        }
        return .none

      case .home(.howToPlayButtonTapped):
        state.onboarding = .init(presentationStyle: .help)
        return .none

      case .didChangeScenePhase(.active):
        return .run { _ in
          async let register: Void = registerForRemoteNotificationsAsync(
            remoteNotifications: self.remoteNotifications,
            userNotifications: self.userNotifications
          )
          async let refresh = self.refreshServerConfig()
          _ = try await (register, refresh)
        }

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
  }
}

public struct AppView: View {
  let store: StoreOf<AppReducer>
  @ObservedObject var viewStore: ViewStore<ViewState, AppReducer.Action>
  @Environment(\.deviceState) var deviceState

  struct ViewState: Equatable {
    let isGameActive: Bool
    let isOnboardingPresented: Bool

    init(state: AppReducer.State) {
      self.isGameActive = state.game != nil
      self.isOnboardingPresented = state.onboarding != nil
    }
  }

  public init(store: StoreOf<AppReducer>) {
    self.store = store
    self.viewStore = ViewStore(self.store.scope(state: ViewState.init, action: { $0 }))
  }

  public var body: some View {
    Group {
      if !self.viewStore.isOnboardingPresented && !self.viewStore.isGameActive {
        NavigationView {
          HomeView(store: self.store.scope(state: \.home, action: AppReducer.Action.home))
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
                  nub: CubeSceneView.ViewState.NubState?.none,
                  settings: CubeSceneView.ViewState.Settings(
                    enableCubeShadow: appState.home.settings.enableCubeShadow,
                    enableGyroMotion: appState.home.settings.userSettings.enableGyroMotion,
                    showSceneStatistics: appState.home.settings.showSceneStatistics
                  )
                )
              }
            },
            action: { $0 }
          ),
          then: { gameAndSettingsStore in
            GameFeatureView(
              content: CubeView(
                store: gameAndSettingsStore.scope(
                  state: CubeSceneView.ViewState.init(game:nub:settings:),
                  action: { .currentGame(.game(CubeSceneView.ViewAction.to(gameAction: $0))) }
                )
              ),
              store: self.store.scope(state: \.currentGame, action: AppReducer.Action.currentGame)
            )
          }
        )
        .transition(.game)
        .zIndex(1)

        IfLetStore(
          self.store.scope(state: \.onboarding, action: AppReducer.Action.onboarding),
          then: OnboardingView.init(store:)
        )
        .zIndex(2)
      }
    }
    .modifier(DeviceStateModifier())
  }
}

#if DEBUG
  struct AppView_Previews: PreviewProvider {
    static var previews: some View {
      AppView(
        store: .init(
          initialState: .init(),
          reducer: AppReducer()
        )
      )
    }
  }
#endif
