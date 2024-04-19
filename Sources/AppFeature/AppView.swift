import ClientModels
import ComposableArchitecture
import ComposableStoreKit
import CubeCore
import DailyChallengeFeature
import GameCore
import HomeFeature
import NotificationHelpers
import OnboardingFeature
import SharedModels
import Styleguide
import SwiftUI
import ServerConfigPersistenceKey

@Reducer
public struct AppReducer {
  @Reducer(state: .equatable)
  public enum Destination {
    case game(Game)
    case onboarding(Onboarding)
  }

  @ObservableState
  public struct State: Equatable {
    public var appDelegate: AppDelegateReducer.State
    @Presents public var destination: Destination.State?
    @SharedReader(.hasShownFirstLaunchOnboarding) var hasShownFirstLaunchOnboarding = false
    public var home: Home.State
    @Shared(.installationTime) var installationTime = 0
    @SharedReader(.serverConfig) var serverConfig = ServerConfig()
    @Shared(.savedGames) var savedGames = SavedGamesState()

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
    case appDelegate(AppDelegateReducer.Action)
    case destination(PresentationAction<Destination.Action>)
    case didChangeScenePhase(ScenePhase)
    case gameCenter(GameCenterAction)
    case home(Home.Action)
    case paymentTransaction(StoreKitClient.PaymentTransactionObserverEvent)
    case verifyReceiptResponse(Result<ReceiptFinalizationEnvelope, Error>)
  }

  @Dependency(\.gameCenter.turnBasedMatch.load) var loadTurnBasedMatch
  @Dependency(\.database.migrate) var migrate
  @Dependency(\.mainRunLoop.now.date) var now
  @Dependency(\.dictionary.randomCubes) var randomCubes
  @Dependency(\.remoteNotifications) var remoteNotifications
  @Dependency(\.userNotifications) var userNotifications

  public init() {}

  public var body: some ReducerOf<Self> {
    self.core
      .onChange(of: \.destination?.game?.moves) { _, moves in
        Reduce { state, _ in
          guard let game = state.destination?.game, game.isSavable
          else { return .none }

          switch (game.gameContext, game.gameMode) {
          case (.dailyChallenge, .unlimited):
            state.savedGames.dailyChallengeUnlimited = InProgressGame(gameState: game)
          case (.shared, .unlimited), (.solo, .unlimited):
            state.savedGames.unlimited = InProgressGame(gameState: game)
          case (.turnBased, _), (_, .timed):
            return .none
          }
          return .none
        }
      }

    GameCenterLogic()
    StoreKitLogic()
  }

  @ReducerBuilder<State, Action>
  var core: some ReducerOf<Self> {
    Scope(state: \.appDelegate, action: \.appDelegate) {
      AppDelegateReducer()
    }
    Scope(state: \.home, action: \.home) {
      Home()
    }
    Reduce { state, action in
      switch action {
      case .appDelegate(.didFinishLaunching):
        if !state.hasShownFirstLaunchOnboarding {
          state.destination = .onboarding(Onboarding.State(presentationStyle: .firstLaunch))
        }
        if state.installationTime <= 0 {
          state.installationTime = self.now.timeIntervalSinceReferenceDate
        }
        return .run { _ in
          try await self.migrate()
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
            if let inProgressGame = state.savedGames.dailyChallengeUnlimited {
              state.destination = .game(Game.State(inProgressGame: inProgressGame))
            } else {
              // TODO: load/retry
            }

          case .dailyChallengeReport:
            state.destination = nil
            state.home.destination = .dailyChallenge(DailyChallengeReducer.State())
          }
        }

        return .run { _ in completionHandler() }

      case .appDelegate:
        return .none

      case .destination(
        .presented(.game(.destination(.presented(.bottomMenu(.endGameButtonTapped)))))
      ),
        .destination(.presented(.game(.destination(.presented(.gameOver(.task)))))):

        guard let game = state.destination?.game else { return .none }
        switch (game.gameContext, game.gameMode) {
        case (.dailyChallenge, .unlimited):
          state.savedGames.dailyChallengeUnlimited = nil
        case (.solo, .unlimited):
          state.savedGames.unlimited = nil
        default:
          break
        }
        return .none

      case .destination(.presented(.game(.activeGames(.dailyChallengeTapped)))),
        .home(.activeGames(.dailyChallengeTapped)):
        guard let inProgressGame = state.savedGames.dailyChallengeUnlimited
        else { return .none }

        state.destination = .game(Game.State(inProgressGame: inProgressGame))
        return .none

      case .destination(.presented(.game(.activeGames(.soloTapped)))),
        .home(.activeGames(.soloTapped)):
        guard let inProgressGame = state.savedGames.unlimited
        else { return .none }

        state.destination = .game(Game.State(inProgressGame: inProgressGame))
        return .none

      case let .destination(.presented(.game(.activeGames(.turnBasedGameTapped(matchId))))),
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

      case .destination(
        .presented(.game(.destination(.presented(.gameOver(.delegate(.startSoloGame(.timed)))))))
      ),
        .home(.destination(.presented(.solo(.gameButtonTapped(.timed))))):
        state.destination = .game(
          Game.State(
            cubes: self.randomCubes(.en),
            gameContext: .solo,
            gameCurrentTime: self.now,
            gameMode: .timed,
            gameStartTime: self.now,
            isGameLoaded: state.destination?.game?.isGameLoaded == .some(true)
          )
        )
        return .none

      case .destination(
        .presented(
          .game(.destination(.presented(.gameOver(.delegate(.startSoloGame(.unlimited))))))
        )
      ),
        .home(.destination(.presented(.solo(.gameButtonTapped(.unlimited))))):
        state.destination = .game(
          state.savedGames.unlimited
            .map { Game.State(inProgressGame: $0) }
            ?? Game.State(
              cubes: self.randomCubes(.en),
              gameContext: .solo,
              gameCurrentTime: self.now,
              gameMode: .unlimited,
              gameStartTime: self.now,
              isGameLoaded: state.destination?.game?.isGameLoaded == .some(true)
            )
        )
        return .none

      case let .destination(.presented(.onboarding(.delegate(action)))):
        switch action {
        case .getStarted:
          state.destination = nil
          return .none
        }

      case .destination:
        return .none

      case let .home(
        .destination(.presented(.dailyChallenge(.delegate(.startGame(inProgressGame)))))
      ):
        state.destination = .game(Game.State(inProgressGame: inProgressGame))
        return .none

      case .home(.howToPlayButtonTapped):
        state.destination = .onboarding(Onboarding.State(presentationStyle: .help))
        return .none

      case .didChangeScenePhase(.active):
        return .run { [serverConfig = state.$serverConfig] _ in
          async let register: Void = registerForRemoteNotificationsAsync(
            remoteNotifications: self.remoteNotifications,
            userNotifications: self.userNotifications
          )
          async let refresh: Void = serverConfig.persistence.reload()
          _ = await (register, refresh)
        } catch: { _, _ in
        }

      case .didChangeScenePhase:
        return .none

      case .gameCenter:
        return .none

      case .home:
        return .none

      case .paymentTransaction:
        return .none

      case .verifyReceiptResponse:
        return .none
      }
    }
    .ifLet(\.$destination, action: \.destination) {
      Destination.body
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
      switch store.destination {
      case .none:
        NavigationStack {
          HomeView(store: store.scope(state: \.home, action: \.home))
        }
        .zIndex(0)

      case .some(.game):
        if let store = store.scope(state: \.destination?.game, action: \.destination.game) {
          GameView(
            content: CubeView(store: store.scope(state: \.cubeScene, action: \.cubeScene)),
            store: store
          )
          .transition(.game)
          .zIndex(1)
        }

      case .some(.onboarding):
        if let store = store.scope(
          state: \.destination?.onboarding, action: \.destination.onboarding
        ) {
          OnboardingView(store: store)
            .zIndex(2)
        }
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
