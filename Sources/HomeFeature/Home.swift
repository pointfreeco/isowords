import ActiveGamesFeature
import ChangelogFeature
import ClientModels
import ComposableArchitecture
import ComposableGameCenter
import DailyChallengeFeature
import DeviceId
import LeaderboardFeature
import MultiplayerFeature
import Overture
import ServerConfigClient
import SettingsFeature
import SharedModels
import SoloFeature
import SwiftUI
import UserDefaultsClient

public struct ActiveMatchResponse: Equatable {
  public let matches: [ActiveTurnBasedMatch]
  public let hasPastTurnBasedGames: Bool
}

public struct Home: ReducerProtocol {
  public struct State: Equatable {
    public var dailyChallenges: [FetchTodaysDailyChallengeResponse]?
    @PresentationStateOf<Destinations> public var destination
    public var hasChangelog: Bool
    public var hasPastTurnBasedGames: Bool
    @PresentationStateOf<NagBanner> public var nagBanner
    public var savedGames: SavedGamesState {
      didSet {
        guard case var .dailyChallenge(dailyChallengeState) = self.destination
        else { return }
        dailyChallengeState.inProgressDailyChallengeUnlimited =
          self.savedGames.dailyChallengeUnlimited
        self.destination = .dailyChallenge(dailyChallengeState)
      }
    }
    public var settings: Settings.State
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
      hasChangelog: Bool = false,
      hasPastTurnBasedGames: Bool = false,
      nagBanner: NagBanner.State? = nil,
      destination: Destinations.State? = nil,
      savedGames: SavedGamesState = SavedGamesState(),
      settings: Settings.State = .init(),
      turnBasedMatches: [ActiveTurnBasedMatch] = [],
      weekInReview: FetchWeekInReviewResponse? = nil
    ) {
      self.dailyChallenges = dailyChallenges
      self.hasChangelog = hasChangelog
      self.hasPastTurnBasedGames = hasPastTurnBasedGames
      self.savedGames = savedGames
      self.settings = settings
      self.turnBasedMatches = turnBasedMatches
      self.weekInReview = weekInReview
      // NB: Property wrappers must be assigned last
      self.destination = destination
      self.nagBanner = nagBanner
    }

    var hasActiveGames: Bool {
      self.savedGames.dailyChallengeUnlimited != nil
        || self.savedGames.unlimited != nil
        || !self.turnBasedMatches.isEmpty
    }
  }

  public enum Action: Equatable {
    case activeMatchesResponse(TaskResult<ActiveMatchResponse>)
    case activeGames(ActiveGamesAction)
    case authenticationResponse(CurrentPlayerEnvelope)
    case dailyChallengeResponse(TaskResult<[FetchTodaysDailyChallengeResponse]>)
    case destination(PresentationActionOf<Destinations>)
    case gameButtonTapped(GameButtonAction)
    case howToPlayButtonTapped
    case nagBanner(PresentationActionOf<NagBanner>)
    case serverConfigResponse(ServerConfig)
    case settings(Settings.Action)
    case task
    case weekInReviewResponse(TaskResult<FetchWeekInReviewResponse>)
  }

  public enum GameButtonAction: Equatable {
    case dailyChallenge
    case multiplayer
    case solo
  }

  @Dependency(\.apiClient) var apiClient
  @Dependency(\.audioPlayer) var audioPlayer
  @Dependency(\.build) var build
  @Dependency(\.deviceId) var deviceId
  @Dependency(\.gameCenter) var gameCenter
  @Dependency(\.mainRunLoop) var mainRunLoop
  @Dependency(\.serverConfig) var serverConfig
  @Dependency(\.timeZone) var timeZone
  @Dependency(\.userDefaults) var userDefaults

  public init() {}

  public var body: some ReducerProtocol<State, Action> {
    Reduce { state, action in
      switch action {
      case let .activeMatchesResponse(.success(response)):
        state.hasPastTurnBasedGames = response.hasPastTurnBasedGames
        state.turnBasedMatches = response.matches
        return .none

      case .activeMatchesResponse(.failure):
        return .none

      case let .activeGames(.turnBasedGameMenuItemTapped(.deleteMatch(matchId))):
        return .run { send in
          let localPlayer = self.gameCenter.localPlayer.localPlayer()

          do {
            let match = try await self.gameCenter.turnBasedMatch.load(matchId)
            let currentParticipantIsLocalPlayer =
              match.currentParticipant?.player?.gamePlayerId == localPlayer.gamePlayerId

            if currentParticipantIsLocalPlayer {
              try await self.gameCenter.turnBasedMatch
                .endMatchInTurn(
                  .init(
                    for: match.matchId,
                    matchData: match.matchData ?? Data(),
                    localPlayerId: localPlayer.gamePlayerId,
                    localPlayerMatchOutcome: .quit,
                    message: "\(localPlayer.displayName) forfeited the match."
                  )
                )
            } else {
              try await self.gameCenter.turnBasedMatch
                .participantQuitOutOfTurn(match.matchId)
            }
          } catch {}

          await send(
            .activeMatchesResponse(
              TaskResult {
                try await self.gameCenter.loadActiveMatches(now: self.mainRunLoop.now.date)
              }
            ),
            animation: .default
          )

          await self.audioPlayer.play(.uiSfxActionDestructive)
        }

      case .activeGames(.turnBasedGameMenuItemTapped(.rematch)):
        return .none

      case let .activeGames(.turnBasedGameMenuItemTapped(.sendReminder(matchId, otherPlayerIndex))):
        return .fireAndForget {
          try await self.gameCenter.turnBasedMatch.sendReminder(
            .init(
              for: matchId,
              to: [otherPlayerIndex.rawValue],
              localizableMessageKey: "It’s your turn now!",
              arguments: []
            )
          )
        }

      case .activeGames:
        return .none

      case let .authenticationResponse(currentPlayerEnvelope):
        state.settings.sendDailyChallengeReminder =
          currentPlayerEnvelope.player.sendDailyChallengeReminder
        state.settings.sendDailyChallengeSummary =
          currentPlayerEnvelope.player.sendDailyChallengeSummary

        let now = self.mainRunLoop.now.date.timeIntervalSinceReferenceDate
        let itsNagTime =
          Int(now - self.userDefaults.installationTime)
          >= self.serverConfig.config().upgradeInterstitial.nagBannerAfterInstallDuration
        let isFullGamePurchased =
          currentPlayerEnvelope.appleReceipt?.receipt.originalPurchaseDate != nil

        state.nagBanner =
          !isFullGamePurchased && itsNagTime
          ? NagBanner.State()
          : nil

        return .none

      case let .dailyChallengeResponse(.success(dailyChallenges)):
        state.dailyChallenges = dailyChallenges
        return .none

      case .dailyChallengeResponse(.failure):
        state.dailyChallenges = []
        return .none

        // TODO: Repro this compiler bug more simply?
        // TODO: Does `any Hashable` have this issue or can we pattern match more directly?
      case .destination(.present(AnyHashable(Destinations.ID.dailyChallenge), _)):
        state.destination = .dailyChallenge(
          .init(
            dailyChallenges: state.dailyChallenges ?? [],
            inProgressDailyChallengeUnlimited: state.savedGames.dailyChallengeUnlimited
          )
        )
        return .none

      case .destination(.present(AnyHashable(Destinations.ID.leaderboard), _)):
        state.destination = .leaderboard(
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
        return .none

      case .destination(.present(AnyHashable(Destinations.ID.multiplayer), _)):
        state.destination = .multiplayer(.init(hasPastGames: state.hasPastTurnBasedGames))
        return .none

      case .destination(.present(AnyHashable(Destinations.ID.solo), _)):
        state.destination = .solo(.init(inProgressGame: state.savedGames.unlimited))
        return .none

      case .destination:
        return .none

      case .gameButtonTapped:
        return .none

      case .howToPlayButtonTapped:
        return .none

      case let .serverConfigResponse(serverConfig):
        state.hasChangelog = serverConfig.newestBuild > self.build.number()
        return .none

      case .nagBanner(.presented(.upgradeInterstitial(.presented(.delegate(.fullGamePurchased))))):
        state.nagBanner = nil
        return .none

      case .nagBanner:
        return .none

      case .settings:
        return .none

      case .task:
        return .run { send in
          async let authenticate: Void = self.authenticate(send: send)
          await self.listenForGameCenterEvents(send: send)
          _ = await authenticate
        }
        .animation()

      case .weekInReviewResponse(.failure):
        return .none

      case let .weekInReviewResponse(.success(response)):
        state.weekInReview = response
        return .none
      }
    }
    .presentationDestination(state: \.$destination, action: /Action.destination) {
      Destinations()
    }
    .presentationDestination(state: \.$nagBanner, action: /Action.nagBanner) {
      NagBanner()
    }
    .debug()

    Scope(state: \.settings, action: /Action.settings) {
      Settings()
    }
  }

  public struct Destinations: ReducerProtocol {
    public enum ID: Hashable {
      case dailyChallenge
      case leaderboard
      case multiplayer
      case solo
    }

    public enum State: Equatable {
      case changelog(ChangelogReducer.State)
      case dailyChallenge(DailyChallengeReducer.State)
      case leaderboard(Leaderboard.State)
      case multiplayer(Multiplayer.State)
      case settings
      case solo(Solo.State)
    }

    public enum Action: Equatable {
      case changelog(ChangelogReducer.Action)
      case dailyChallenge(DailyChallengeReducer.Action)
      case leaderboard(Leaderboard.Action)
      case multiplayer(Multiplayer.Action)
      case solo(Solo.Action)
    }

    public var body: some ReducerProtocol<State, Action> {
      ScopeCase(
        state: /State.changelog,
        action: /Action.changelog
      ) {
        ChangelogReducer()
      }
      ScopeCase(
        state: /State.dailyChallenge,
        action: /Action.dailyChallenge
      ) {
        DailyChallengeReducer()
      }
      ScopeCase(
        state: /State.leaderboard,
        action: /Action.leaderboard
      ) {
        Leaderboard()
      }
      ScopeCase(
        state: /State.multiplayer,
        action: /Action.multiplayer
      ) {
        Multiplayer()
      }
      ScopeCase(
        state: /State.solo,
        action: /Action.solo
      ) {
        Solo()
      }
    }
  }

  private func authenticate(send: Send<Action>) async {
    do {
//      try? await self.gameCenter.localPlayer.authenticate()

      let localPlayer = self.gameCenter.localPlayer.localPlayer()
      let currentPlayerEnvelope = try await self.apiClient.authenticate(
        .init(
          deviceId: .init(rawValue: self.deviceId.id()),
          displayName: localPlayer.isAuthenticated ? localPlayer.displayName : nil,
          gameCenterLocalPlayerId: localPlayer.isAuthenticated
            ? .init(rawValue: localPlayer.gamePlayerId.rawValue)
            : nil,
          timeZone: self.timeZone.identifier
        )
      )
      await send(.authenticationResponse(currentPlayerEnvelope))

      async let serverConfigResponse: Void = send(
        .serverConfigResponse(self.serverConfig.refresh())
      )

      async let dailyChallengeResponse: Void = send(
        .dailyChallengeResponse(
          TaskResult {
            try await self.apiClient.apiRequest(
              route: .dailyChallenge(.today(language: .en)),
              as: [FetchTodaysDailyChallengeResponse].self
            )
          }
        )
      )
      async let weekInReviewResponse: Void = send(
        .weekInReviewResponse(
          TaskResult {
            try await self.apiClient.apiRequest(
              route: .leaderboard(.weekInReview(language: .en)),
              as: FetchWeekInReviewResponse.self
            )
          }
        )
      )
      async let activeMatchesResponse: Void = send(
        .activeMatchesResponse(
          TaskResult {
            try await self.gameCenter
              .loadActiveMatches(now: self.mainRunLoop.now.date)
          }
        )
      )
      _ = try await (
        serverConfigResponse, dailyChallengeResponse, weekInReviewResponse, activeMatchesResponse
      )
    } catch {}
  }

  private func listenForGameCenterEvents(send: Send<Action>) async {
    for await event in self.gameCenter.localPlayer.listener() {
      switch event {
      case .turnBased(.matchEnded),
        .turnBased(.receivedTurnEventForMatch):
        await send(
          .activeMatchesResponse(
            TaskResult {
              try await self.gameCenter
                .loadActiveMatches(now: self.mainRunLoop.now.date)
            }
          )
        )
      default:
        break
      }
    }
  }

}

extension GameCenterClient {
  fileprivate func loadActiveMatches(
    now: Date
  ) async throws -> ActiveMatchResponse {
    let localPlayer = self.localPlayer.localPlayer()
    let matches = try await self.turnBasedMatch.loadMatches()
    let activeMatches = matches.activeMatches(for: localPlayer, at: now)
    let hasPastTurnBasedGames = matches.contains { $0.status == .ended }
    return ActiveMatchResponse(matches: activeMatches, hasPastTurnBasedGames: hasPastTurnBasedGames)
  }
}

public struct HomeView: View {
  struct ViewState: Equatable {
    let hasActiveGames: Bool
    let hasChangelog: Bool
    let isNagBannerVisible: Bool

    init(state: Home.State) {
      self.hasActiveGames =
        state.savedGames.dailyChallengeUnlimited != nil
        || state.savedGames.unlimited != nil
        || !state.turnBasedMatches.isEmpty
      self.hasChangelog = state.hasChangelog
      self.isNagBannerVisible = state.nagBanner != nil
    }
  }

  @Environment(\.colorScheme) var colorScheme
  let store: StoreOf<Home>
  @ObservedObject var viewStore: ViewStore<ViewState, Home.Action>

  public init(store: StoreOf<Home>) {
    self.store = store
    self.viewStore = ViewStore(store.scope(state: ViewState.init))
  }

  public var body: some View {
    ZStack(alignment: .bottom) {
      ScrollView {
        VStack(spacing: .grid(12)) {
          VStack(spacing: .grid(6)) {
            HStack {
              CubeIconView(shake: self.viewStore.hasChangelog) {
                self.viewStore.send(.destination(.present(.changelog(ChangelogReducer.State()))))
              }

              Spacer()

              Button(action: { self.viewStore.send(.howToPlayButtonTapped, animation: .default) }) {
                Image(systemName: "questionmark.circle")
              }

              Button {
                viewStore.send(.destination(.present(.settings)))
              } label: {
                Image(systemName: "gear")
              }
            }
            .font(.system(size: 24))
            .foregroundColor(self.colorScheme == .dark ? .hex(0xF2E29F) : .isowordsBlack)
            .adaptivePadding(.horizontal)

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
                  action: Home.Action.activeGames
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
        .adaptivePadding(.vertical, .grid(4))
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

      IfLetStore(
        self.store.scope(state: \.nagBanner, action: { .nagBanner(.presented($0)) }),
        then: NagBannerView.init(store:)
      )
    }
    .navigationBarHidden(true)
    .sheet(
      store: self.store.scope(state: \.$destination, action: Home.Action.destination),
      state: /Home.Destinations.State.changelog,
      action: Home.Destinations.Action.changelog,
      content: ChangelogView.init(store:)
    )
    .navigationDestination(
      store: self.store.scope(state: \.$destination, action: Home.Action.destination),
      state: /Home.Destinations.State.dailyChallenge,
      action: Home.Destinations.Action.dailyChallenge,
      destination: DailyChallengeView.init(store:)
    )
    .navigationDestination(
      store: self.store.scope(state: \.$destination, action: Home.Action.destination),
      state: /Home.Destinations.State.leaderboard,
      action: Home.Destinations.Action.leaderboard,
      destination: LeaderboardView.init(store:)
    )
    .navigationDestination(
      store: self.store.scope(state: \.$destination, action: Home.Action.destination),
      state: /Home.Destinations.State.multiplayer,
      action: Home.Destinations.Action.multiplayer,
      destination: MultiplayerView.init(store:)
    )
    .navigationDestination(
      store: self.store.scope(state: \.$destination, action: Home.Action.destination),
      state: /Home.Destinations.State.settings,
      action: { $0 }
    ) { _ in
      SettingsView(
        store: self.store.scope(state: \.settings, action: Home.Action.settings),
        navPresentationStyle: .navigation
      )
    }
    .navigationDestination(
      store: self.store.scope(state: \.$destination, action: Home.Action.destination),
      state: /Home.Destinations.State.solo,
      action: Home.Destinations.Action.solo,
      destination: SoloView.init(store:)
    )
    .task { await self.viewStore.send(.task).finish() }
  }
}

private struct CubeIconView: View {
  let action: () -> Void
  let shake: Bool

  init(
    shake: Bool,
    action: @escaping () -> Void
  ) {
    self.action = action
    self.shake = shake
  }

  var body: some View {
    Button(action: self.action) {
      Image(systemName: "cube.fill")
        .font(.system(size: 24))
        .modifier(ShakeEffect(animatableData: CGFloat(self.shake ? 1 : 0)))
        .animation(.easeInOut(duration: 1), value: self.shake)
    }
  }
}

private struct ShakeEffect: GeometryEffect {
  var animatableData: CGFloat

  func effectValue(size: CGSize) -> ProjectionTransform {
    ProjectionTransform(
      CGAffineTransform(rotationAngle: -.pi / 30 * sin(animatableData * .pi * 10))
    )
  }
}

#if DEBUG
  @testable import ComposableGameCenter
  import SwiftUIHelpers

  struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
      Preview {
        NavigationStack {
          HomeView(store: .home)
        }
      }
    }
  }

  extension Store where State == Home.State, Action == Home.Action {
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
      reducer: Home()
    )
  }
#endif
