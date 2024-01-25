import ClientModels
import ComposableArchitecture
import ComposableStoreKit
import CubeCore
import GameCore
import HomeFeature
import NotificationHelpers
import OnboardingFeature
import SharedModels
import Styleguide
import SwiftUI

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

    var firstLaunchOnboarding: Onboarding.State? {
      switch self.destination {
      case .game, .none:
        return nil

      case let .onboarding(onboarding):
        switch onboarding.presentationStyle {
        case .demo, .help:
          return nil

        case .firstLaunch:
          return onboarding
        }
      }
    }
  }

  public enum Action {
    case appDelegate(AppDelegateReducer.Action)
    case destination(PresentationAction<Destination.Action>)
    case didChangeScenePhase(ScenePhase)
    case gameCenter(GameCenterAction)
    case home(Home.Action)
    case paymentTransaction(StoreKitClient.PaymentTransactionObserverEvent)
    case savedGamesLoaded(Result<SavedGamesState, Error>)
    case verifyReceiptResponse(Result<ReceiptFinalizationEnvelope, Error>)
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

  public var body: some ReducerOf<Self> {
    self.core
      .onChange(of: \.destination?.game?.moves) { _, moves in
        Reduce { state, _ in
          guard let game = state.destination?.game, game.isSavable
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
      }
      .onChange(of: \.home.savedGames) { _, savedGames in
        Reduce { _, action in
          if case .savedGamesLoaded(.success) = action { return .none }
          return .run { _ in
            try await self.fileClient.save(games: savedGames)
          }
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
        if !self.userDefaults.hasShownFirstLaunchOnboarding {
          state.destination = .onboarding(Onboarding.State(presentationStyle: .firstLaunch))
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
              Result { try await self.fileClient.loadSavedGames() }
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
              state.destination = .game(Game.State(inProgressGame: inProgressGame))
            } else {
              // TODO: load/retry
            }

          case .dailyChallengeReport:
            state.destination = nil
            state.home.destination = .dailyChallenge(.init())
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
          state.home.savedGames.dailyChallengeUnlimited = nil
        case (.solo, .unlimited):
          state.home.savedGames.unlimited = nil
        default:
          break
        }
        return .none

      case .destination(.presented(.game(.activeGames(.dailyChallengeTapped)))),
        .home(.activeGames(.dailyChallengeTapped)):
        guard let inProgressGame = state.home.savedGames.dailyChallengeUnlimited
        else { return .none }

        state.destination = .game(Game.State(inProgressGame: inProgressGame))
        return .none

      case .destination(.presented(.game(.activeGames(.soloTapped)))),
        .home(.activeGames(.soloTapped)):
        guard let inProgressGame = state.home.savedGames.unlimited
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
          state.home.savedGames.unlimited
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

      case let .home(.dailyChallengeResponse(.success(dailyChallenges))):
        if dailyChallenges.unlimited?.dailyChallenge.id
          != state.home.savedGames.dailyChallengeUnlimited?.gameContext.dailyChallenge
        {
          state.home.savedGames.dailyChallengeUnlimited = nil
          return .run { [savedGames = state.home.savedGames] _ in
            try await self.fileClient.save(games: savedGames)
          }
        }
        return .none

      case .home(.howToPlayButtonTapped):
        state.destination = .onboarding(Onboarding.State(presentationStyle: .help))
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
    .ifLet(\.$destination, action: \.destination)
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
      switch store.scope(state: \.destination, action: \.destination.presented)?.case {
      case .none:
        NavigationStack {
          HomeView(store: store.scope(state: \.home, action: \.home))
        }
        .zIndex(0)

      case let .some(.game(store)):
        GameView(
          content: CubeView(store: store.scope(state: \.cubeScene, action: \.cubeScene)),
          store: store
        )
        .transition(.game)
        .zIndex(1)

      case let .some(.onboarding(store)):
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
