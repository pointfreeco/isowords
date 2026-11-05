import ActiveGamesFeature
import ApiClient
import ClientModels
import ComposableArchitecture
import ComposableGameCenter
import ComposableStoreKit
import ComposableUserNotifications
import CubeCore
import DailyChallengeFeature
import Dependencies
import FileClient
import GameCore
import GameOverFeature
import HomeFeature
import MultiplayerFeature
import NotificationHelpers
import OnboardingFeature
import RemoteNotificationsClient
import ServerConfig
import SharedModels
import SoloFeature
import Styleguide
import SwiftUI
import UserDefaultsClient

@Feature
public struct AppReducer {
  @Feature
  public enum Destination {
    case game(Game)
    case onboarding(Onboarding)
  }

  public struct State {
    public var appDelegate: AppDelegateReducer.State
    public var destination: Destination.State?
    public var home: Home.State

    public init(
      appDelegate: AppDelegateReducer.State = AppDelegateReducer.State(),
      destination: Destination.State? = nil,
      home: Home.State = Home.State()
    ) {
      self.appDelegate = appDelegate
      self.destination = destination
      self.home = home
    }
  }

  public enum Action {
    case didChangeScenePhase(ScenePhase)
  }

  @Dependency(\.apiClient) var apiClient
  @Dependency(\.apiClient.currentPlayer) var currentPlayer
  @Dependency(\.fileClient) var fileClient
  @Dependency(\.gameCenter) var gameCenter
  @Dependency(\.database.migrate) var migrate
  @FeatureEnvironment(\.date.now) var now
  @Dependency(\.dictionary.randomCubes) var randomCubes
  @Dependency(\.serverConfig.refresh) var refreshServerConfig
  @Dependency(\.remoteNotifications) var remoteNotifications
  @Dependency(\.database.saveGame) var saveGame
  @Dependency(\.storeKit) var storeKit
  @Dependency(\.userDefaults) var userDefaults
  @Dependency(\.userNotifications) var userNotifications

  @FeatureBindable var store = FeatureStore<State, Action>()
  @FeatureState var persistedSavedGames: SavedGamesState?

  public init() {}

  public var body: some Feature {
    Features {
      Scope(\.appDelegate) {
        AppDelegateReducer()
      }
      Scope(\.home) {
        Home()
      }
      Update { state, action in
        switch action {
        case .didChangeScenePhase(.active):
          store.addTask {
            async let register: Void = registerForRemoteNotificationsAsync(
              remoteNotifications: remoteNotifications,
              userNotifications: userNotifications
            )
            async let refresh = refreshServerConfig()
            _ = try? await (register, refresh)
          }

        case .didChangeScenePhase:
          break
        }
      }
      .ifLet(\.destination) {
        Destination.body
      }
    }
    .onEvent(ActiveGames.Event.self) { event, state -> FeatureEventPropagation in
      switch event {
      case .dailyChallengeTapped:
        guard let inProgressGame = state.home.savedGames.dailyChallengeUnlimited
        else { break }
        state.destination = .game(Game.State(inProgressGame: inProgressGame))

      case .soloTapped:
        guard let inProgressGame = state.home.savedGames.unlimited
        else { break }
        state.destination = .game(Game.State(inProgressGame: inProgressGame))

      case .turnBasedGameMenuItemTapped(.rematch(let matchId)):
        store.addTask {
          try await rematch(matchId)
        }

      case .turnBasedGameTapped(let matchId):
        store.addTask {
          try await openTurnBasedMatch(id: matchId)
        }

      case .turnBasedGameMenuItemTapped:
        return .continue
      }
      return .stop
    }
    .onEvent(AppDelegateReducer.DidReceiveNotificationResponse.self) { response, state in
      handle(response, state: &state)
    }
    .onEvent(DailyChallengeReducer.StartGame.self) { inProgressGame, state in
      state.destination = .game(Game.State(inProgressGame: inProgressGame))
    }
    .onEvent(GameOver.Event.self) { event, state -> FeatureEventPropagation in
      switch event {
      case .rematch:
        guard
          case .game(let game) = state.destination,
          let turnBasedMatch = game.gameContext.turnBased
        else { return .stop }

        state.destination = nil
        store.addTask {
          try await rematch(turnBasedMatch.match.matchId)
        }
        return .stop

      case .startSoloGame(let gameMode):
        startSoloGame(gameMode, state: &state)
        return .stop

      case .dismissGame, .gameSubmitted, .startGame:
        return .continue
      }
    }
    .onEvent(Home.HowToPlay.self) { _, state in
      state.destination = .onboarding(Onboarding.State(presentationStyle: .help))
    }
    .onEvent(Onboarding.GetStarted.self) { _, state in
      state.destination = nil
    }
    .onEvent(PastGame.OpenMatch.self) { match, _ in
      store.addTask {
        try await handleTurnBasedMatch(match, didBecomeActive: true)
      }
    }
    .onEvent(Solo.StartGame.self) { gameMode, state in
      startSoloGame(gameMode, state: &state)
    }
    .onChange(of: store.destination?.game?.moves) { _, _, state in
      guard let game = state.destination?.game, game.isSavable
      else { return }

      switch (game.gameContext, game.gameMode) {
      case (.dailyChallenge, .unlimited):
        state.home.savedGames.dailyChallengeUnlimited = InProgressGame(gameState: game)
      case (.shared, .unlimited), (.solo, .unlimited):
        state.home.savedGames.unlimited = InProgressGame(gameState: game)
      case (.turnBased, _), (_, .timed):
        break
      }
    }
    .onChange(of: store.destination?.game?.isGameOver == true) { _, isGameOver, state in
      guard isGameOver, let game = state.destination?.game
      else { return }

      switch (game.gameContext, game.gameMode) {
      case (.dailyChallenge, .unlimited):
        state.home.savedGames.dailyChallengeUnlimited = nil
      case (.solo, .unlimited):
        state.home.savedGames.unlimited = nil
      default:
        break
      }
    }
    .onChange(of: store.home.savedGames) { _, savedGames, _ in
      guard savedGames != persistedSavedGames
      else { return }

      persistedSavedGames = savedGames
      store.addTask {
        try await fileClient.save(games: savedGames)
      }
    }
    .onChange(of: store.destination == nil) { _, isHomeVisible, _ in
      guard isHomeVisible else { return }
      store.addTask {
        try store.home.refresh()
      }
    }
    .onMount { state in
      if !userDefaults.hasShownFirstLaunchOnboarding {
        state.destination = .onboarding(Onboarding.State(presentationStyle: .firstLaunch))
      }

      store.addTask {
        async let migrate: Void = migrate()
        if userDefaults.installationTime <= 0 {
          await userDefaults.setInstallationTime(
            now.timeIntervalSinceReferenceDate
          )
        }
        if let savedGames = try? await fileClient.loadSavedGames() {
          try await savedGamesLoaded(savedGames)
        }
        _ = try await migrate
      }
      store.addTask {
        try await listenForGameCenterEvents()
      }
      store.addTask {
        await observePaymentTransactions()
      }
    }
  }

  @MainActor
  private func savedGamesLoaded(_ savedGames: SavedGamesState) throws {
    persistedSavedGames = savedGames
    try store.modify { $0.home.savedGames = savedGames }
  }

  private func startSoloGame(_ gameMode: GameMode, state: inout State) {
    switch gameMode {
    case .timed:
      state.destination = .game(
        Game.State(
          cubes: randomCubes(.en),
          gameContext: .solo,
          gameCurrentTime: now,
          gameMode: .timed,
          gameStartTime: now,
          isGameLoaded: state.destination?.game?.isGameLoaded == .some(true)
        )
      )

    case .unlimited:
      state.destination = .game(
        state.home.savedGames.unlimited
          .map { Game.State(inProgressGame: $0) }
          ?? Game.State(
            cubes: randomCubes(.en),
            gameContext: .solo,
            gameCurrentTime: now,
            gameMode: .unlimited,
            gameStartTime: now,
            isGameLoaded: state.destination?.game?.isGameLoaded == .some(true)
          )
      )
    }
  }

  private func handle(
    _ response: UserNotificationClient.Notification.Response,
    state: inout State
  ) {
    guard
      let data = try? JSONSerialization.data(
        withJSONObject: response.notification.request.content.userInfo
      ),
      let pushNotificationContent = try? JSONDecoder()
        .decode(PushNotificationContent.self, from: data)
    else { return }

    switch pushNotificationContent {
    case .dailyChallengeEndsSoon:
      if let inProgressGame = state.home.savedGames.dailyChallengeUnlimited {
        state.destination = .game(Game.State(inProgressGame: inProgressGame))
      } else {
        // TODO: load/retry
      }

    case .dailyChallengeReport:
      state.destination = nil
      state.home.destination = .dailyChallenge(.init())
    }
  }
}

public struct AppView: View {
  let store: StoreOf<AppReducer>
  @Environment(\.deviceState) var deviceState

  public init(store: StoreOf<AppReducer>) {
    self.store = store
  }

  public var body: some View {
    Group {
      switch store.scope(\.destination)?.enumeration {
      case .none:
        NavigationStack {
          HomeView(store: store.scope(\.home))
        }
        .zIndex(0)

      case .game(let store)?:
        GameView(
          content: CubeView(
            store: store,
            state: \.cubeScene,
            action: CubeSceneView.ViewAction.to(gameAction:)
          ),
          store: store
        )
        .transition(.game)
        .zIndex(1)

      case .onboarding(let store)?:
        OnboardingView(store: store)
          .zIndex(2)
      }
    }
    .modifier(DeviceStateModifier())
  }
}

#Preview {
  AppView(
    store: Store(initialState: AppReducer.State()) {
      AppReducer()
    }
  )
}
