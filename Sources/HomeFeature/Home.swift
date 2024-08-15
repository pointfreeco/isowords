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

@Reducer
public struct Home {
  @Reducer(state: .equatable)
  public enum Destination {
    case changelog(ChangelogReducer)
    case dailyChallenge(DailyChallengeReducer)
    case leaderboard(Leaderboard)
    case multiplayer(Multiplayer)
    case settings(Settings)
    case solo(Solo)
  }

  @ObservableState
  public struct State: Equatable {
    public var dailyChallenges: [FetchTodaysDailyChallengeResponse]?
    @Presents public var destination: Destination.State?
    public var hasChangelog: Bool
    public var hasPastTurnBasedGames: Bool
    @Presents public var nagBanner: NagBanner.State?
    public var savedGames: SavedGamesState {
      didSet {
        guard var dailyChallengeState = self.destination?.dailyChallenge
        else { return }
        dailyChallengeState.inProgressDailyChallengeUnlimited =
          self.savedGames.dailyChallengeUnlimited
        self.destination = .dailyChallenge(dailyChallengeState)
      }
    }
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
      destination: Destination.State? = nil,
      savedGames: SavedGamesState = SavedGamesState(),
      turnBasedMatches: [ActiveTurnBasedMatch] = [],
      weekInReview: FetchWeekInReviewResponse? = nil
    ) {
      self.dailyChallenges = dailyChallenges
      self.destination = destination
      self.hasChangelog = hasChangelog
      self.hasPastTurnBasedGames = hasPastTurnBasedGames
      self.nagBanner = nagBanner
      self.savedGames = savedGames
      self.turnBasedMatches = turnBasedMatches
      self.weekInReview = weekInReview
    }

    var hasActiveGames: Bool {
      self.savedGames.dailyChallengeUnlimited != nil
        || self.savedGames.unlimited != nil
        || !self.turnBasedMatches.isEmpty
    }
  }

  public enum Action {
    case activeMatchesResponse(Result<ActiveMatchResponse, Error>)
    case activeGames(ActiveGamesAction)
    case authenticationResponse(CurrentPlayerEnvelope)
    case cubeButtonTapped
    case dailyChallengeButtonTapped
    case dailyChallengeResponse(Result<[FetchTodaysDailyChallengeResponse], Error>)
    case destination(PresentationAction<Destination.Action>)
    case gameButtonTapped(GameButtonAction)
    case howToPlayButtonTapped
    case leaderboardButtonTapped
    case multiplayerButtonTapped
    case nagBanner(PresentationAction<NagBanner.Action>)
    case serverConfigResponse(ServerConfig)
    case settingsButtonTapped
    case soloButtonTapped
    case task
    case weekInReviewResponse(Result<FetchWeekInReviewResponse, Error>)
  }

  public enum GameButtonAction: Equatable {
    case dailyChallenge
    case multiplayer
    case solo
  }

  @Dependency(\.apiClient) var apiClient
  @Dependency(\.build.number) var buildNumber
  @Dependency(\.deviceId) var deviceId
  @Dependency(\.gameCenter) var gameCenter
  @Dependency(\.mainRunLoop.now.date) var now
  @Dependency(\.audioPlayer.play) var playSound
  @Dependency(\.serverConfig) var serverConfig
  @Dependency(\.timeZone) var timeZone
  @Dependency(\.userDefaults) var userDefaults

  public init() {}

  public var body: some ReducerOf<Self> {
    Reduce(self.core)
      .ifLet(\.$destination, action: \.destination) {
        Destination.body
      }
      .ifLet(\.$nagBanner, action: \.nagBanner) {
        NagBanner()
      }
  }

  private func core(state: inout State, action: Action) -> EffectOf<Self> {
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
            Result {
              try await self.gameCenter.loadActiveMatches(now: self.now)
            }
          ),
          animation: .default
        )

        await self.playSound(.uiSfxActionDestructive)
      }

    case .activeGames(.turnBasedGameMenuItemTapped(.rematch)):
      return .none

    case let .activeGames(.turnBasedGameMenuItemTapped(.sendReminder(matchId, otherPlayerIndex))):
      return .run { _ in
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
      let now = self.now.timeIntervalSinceReferenceDate
      let itsNagTime =
        Int(now - self.userDefaults.installationTime)
        >= self.serverConfig.config().upgradeInterstitial.nagBannerAfterInstallDuration
      let isFullGamePurchased =
        currentPlayerEnvelope.appleReceipt?.receipt.originalPurchaseDate != nil

      state.nagBanner =
        !isFullGamePurchased && itsNagTime
        ? .init()
        : nil

      return .none

    case .cubeButtonTapped:
      state.destination = .changelog(ChangelogReducer.State())
      return .none

    case .dailyChallengeButtonTapped:
      state.destination = .dailyChallenge(
        .init(
          dailyChallenges: state.dailyChallenges ?? [],
          inProgressDailyChallengeUnlimited: state.savedGames.dailyChallengeUnlimited
        )
      )
      return .none

    case let .dailyChallengeResponse(.success(dailyChallenges)):
      state.dailyChallenges = dailyChallenges
      return .none

    case .dailyChallengeResponse(.failure):
      state.dailyChallenges = []
      return .none

    case .destination:
      return .none

    case .gameButtonTapped:
      return .none

    case .howToPlayButtonTapped:
      return .none

    case let .serverConfigResponse(serverConfig):
      state.hasChangelog = serverConfig.newestBuild > self.buildNumber()
      return .none

    case .leaderboardButtonTapped:
      state.destination = .leaderboard(Leaderboard.State())
      return .none

    case .multiplayerButtonTapped:
      state.destination = .multiplayer(.init(hasPastGames: state.hasPastTurnBasedGames))
      return .none

    case .nagBanner:
      return .none

    case .settingsButtonTapped:
      state.destination = .settings(Settings.State())
      return .none

    case .soloButtonTapped:
      state.destination = .solo(.init(inProgressGame: state.savedGames.unlimited))
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

  private func authenticate(send: Send<Action>) async {
    do {
      try? await self.gameCenter.localPlayer.authenticate()

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
          Result {
            try await self.apiClient.apiRequest(
              route: .dailyChallenge(.today(language: .en)),
              as: [FetchTodaysDailyChallengeResponse].self
            )
          }
        )
      )
      async let weekInReviewResponse: Void = send(
        .weekInReviewResponse(
          Result {
            try await self.apiClient.apiRequest(
              route: .leaderboard(.weekInReview(language: .en)),
              as: FetchWeekInReviewResponse.self
            )
          }
        )
      )
      async let activeMatchesResponse: Void = send(
        .activeMatchesResponse(
          Result {
            try await self.gameCenter
              .loadActiveMatches(now: self.now)
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
            Result {
              try await self.gameCenter
                .loadActiveMatches(now: self.now)
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
  @Environment(\.colorScheme) var colorScheme
  @Bindable var store: StoreOf<Home>

  public init(store: StoreOf<Home>) {
    self.store = store
  }

  public var body: some View {
    ZStack(alignment: .bottom) {
      ScrollView {
        VStack(spacing: .grid(12)) {
          VStack(spacing: .grid(6)) {
            HStack {
              CubeIconView(shake: store.hasChangelog) {
                store.send(.cubeButtonTapped)
              }

              Spacer()

              Button {
                store.send(.howToPlayButtonTapped, animation: .default)
              } label: {
                Image(systemName: "questionmark.circle")
              }

              Button {
                store.send(.settingsButtonTapped)
              } label: {
                Image(systemName: "gear")
              }
            }
            .font(.system(size: 24))
            .foregroundColor(self.colorScheme == .dark ? .hex(0xF2E29F) : .isowordsBlack)
            .adaptivePadding(.horizontal)

            DailyChallengeHeaderView(store: store)
              .screenEdgePadding(.horizontal)
          }

          if store.hasActiveGames {
            VStack(alignment: .leading) {
              Text("Active games")
                .adaptiveFont(.matterMedium, size: 16)
                .foregroundColor(self.colorScheme == .dark ? .hex(0xEBAE83) : .isowordsBlack)
                .screenEdgePadding(.horizontal)

              ActiveGamesView(
                store: store.scope(state: \.activeGames, action: \.activeGames),
                showMenuItems: true
              )
              .foregroundColor(self.colorScheme == .dark ? .hex(0xE9A27C) : .isowordsBlack)
            }
          }

          StartNewGameView(store: store)
            .screenEdgePadding(.horizontal)
          LeaderboardLinkView(store: store)
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

        if store.nagBanner != nil {
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

      if let store = store.scope(state: \.nagBanner, action: \.nagBanner.presented) {
        NagBannerView(store: store)
      }
    }
    .navigationBarHidden(true)
    .navigationDestination(
      item: $store.scope(state: \.destination?.settings, action: \.destination.settings)
    ) { store in
      SettingsView(store: store, navPresentationStyle: .navigation)
    }
    .sheet(
      item: $store.scope(state: \.destination?.changelog, action: \.destination.changelog)
    ) { store in
      ChangelogView(store: store)
    }
    .task { await store.send(.task).finish() }
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
        NavigationView {
          HomeView(store: .home)
        }
      }
    }
  }

  extension Store where State == Home.State, Action == Home.Action {
    static let home = Store(
      initialState: update(Home.State()) {
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
      }
    ) {
      Home()
    }
  }
#endif
