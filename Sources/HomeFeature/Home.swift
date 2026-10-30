import ActiveGamesFeature
import ChangelogFeature
import ClientModels
import ComposableArchitecture
import ComposableGameCenter
import DailyChallengeFeature
import Dependencies
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

struct ActiveMatchResponse: Equatable {
  let matches: [ActiveTurnBasedMatch]
  let hasPastTurnBasedGames: Bool
}

@Feature
public struct Home {
  @Feature
  public enum Destination {
    case changelog(ChangelogReducer)
    case dailyChallenge(DailyChallengeReducer)
    case leaderboard(Leaderboard)
    case multiplayer(Multiplayer)
    case settings(Settings)
    case solo(Solo)
  }

  public struct State {
    public var activeGames: ActiveGames.State
    public var dailyChallenges: [FetchTodaysDailyChallengeResponse]?
    public var destination: Destination.State?
    public var hasChangelog: Bool
    public var hasPastTurnBasedGames: Bool
    public var nagBanner: NagBanner.State?
    @Trigger public var refresh
    public var weekInReview: FetchWeekInReviewResponse?

    public var savedGames: SavedGamesState {
      get { self.activeGames.savedGames }
      set { self.activeGames.savedGames = newValue }
    }

    public var turnBasedMatches: [ActiveTurnBasedMatch] {
      get { self.activeGames.turnBasedMatches }
      set { self.activeGames.turnBasedMatches = newValue }
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
      self.activeGames = ActiveGames.State(
        savedGames: savedGames,
        turnBasedMatches: turnBasedMatches
      )
      self.dailyChallenges = dailyChallenges
      self.destination = destination
      self.hasChangelog = hasChangelog
      self.hasPastTurnBasedGames = hasPastTurnBasedGames
      self.nagBanner = nagBanner
      self.weekInReview = weekInReview
    }

    var hasActiveGames: Bool {
      self.savedGames.dailyChallengeUnlimited != nil
        || self.savedGames.unlimited != nil
        || !self.turnBasedMatches.isEmpty
    }
  }

  public enum Action {
    case activeGames(ActiveGames.Action)
    case cubeButtonTapped
    case dailyChallengeButtonTapped
    case destination(Destination.Action)
    case howToPlayButtonTapped
    case leaderboardButtonTapped
    case multiplayerButtonTapped
    case nagBanner(NagBanner.Action)
    case settingsButtonTapped
    case soloButtonTapped
  }

  public struct HowToPlay: FeatureEventKey {
    public init() {}
  }

  @Dependency(\.apiClient) var apiClient
  @Dependency(\.build.number) var buildNumber
  @Dependency(\.deviceId) var deviceId
  @Dependency(\.gameCenter) var gameCenter
  @FeatureEnvironment(\.date.now) var now
  @Dependency(\.audioPlayer.play) var playSound
  @Dependency(\.serverConfig) var serverConfig
  @FeatureEnvironment(\.timeZone) var timeZone
  @Dependency(\.userDefaults) var userDefaults

  @StoreTaskID var loadTask

  public init() {}

  public var body: some Feature {
    Scope(\.activeGames) {
      ActiveGames()
    }
    .onEvent(ActiveGames.Event.self) { event, _ in
      switch event {
      case let .turnBasedGameMenuItemTapped(.deleteMatch(matchId)):
        store.addTask {
          try await deleteMatch(matchId)
        }
        return .stop

      case let .turnBasedGameMenuItemTapped(.sendReminder(matchId, otherPlayerIndex)):
        store.addTask {
          try await gameCenter.turnBasedMatch.sendReminder(
            .init(
              for: matchId,
              to: [otherPlayerIndex.rawValue],
              localizableMessageKey: "It’s your turn now!",
              arguments: []
            )
          )
        }
        return .stop

      case .dailyChallengeTapped, .soloTapped, .turnBasedGameMenuItemTapped(.rematch),
        .turnBasedGameTapped:
        return .continue
      }
    }

    Update { state, action in
      switch action {
      case .activeGames:
        break

      case .cubeButtonTapped:
        state.destination = .changelog(ChangelogReducer.State())

      case .dailyChallengeButtonTapped:
        state.destination = .dailyChallenge(
          .init(
            dailyChallenges: state.dailyChallenges ?? [],
            inProgressDailyChallengeUnlimited: state.savedGames.dailyChallengeUnlimited
          )
        )

      case .destination:
        break

      case .howToPlayButtonTapped:
        store.addTask {
          try await MainActor.run {
            try withAnimation {
              _ = try store.post(HowToPlay())
            }
          }
        }

      case .leaderboardButtonTapped:
        state.destination = .leaderboard(Leaderboard.State())

      case .multiplayerButtonTapped:
        state.destination = .multiplayer(.init(hasPastGames: state.hasPastTurnBasedGames))

      case .nagBanner:
        break

      case .settingsButtonTapped:
        state.destination = .settings(Settings.State())

      case .soloButtonTapped:
        state.destination = .solo(.init(inProgressGame: state.savedGames.unlimited))
      }
    }
    .ifLet(\.destination) {
      Destination.body
    }
    .ifLet(\.nagBanner) {
      NagBanner()
    }
    .onChange(of: store.savedGames.dailyChallengeUnlimited) { state in
      let inProgressGame = state.savedGames.dailyChallengeUnlimited
      try? state.destination?.modify(\.dailyChallenge) {
        $0.inProgressDailyChallengeUnlimited = inProgressGame
      }
    }
    .onMount { _ in
      store.addTask(id: loadTask) {
        try await load()
      }
      store.addTask {
        try await listenForGameCenterEvents()
      }
    }
    .onTrigger(store.refresh) { _ in
      store.addTask(id: loadTask) {
        try await load()
      }
    }
  }

  private func modify(
    animated body: @escaping @Sendable (inout State) -> Void
  ) async throws {
    try await MainActor.run {
      try withAnimation {
        _ = try store.modify(body)
      }
    }
  }

  private func load() async throws {
    try? await self.gameCenter.localPlayer.authenticate()

    let localPlayer = self.gameCenter.localPlayer.localPlayer()
    guard
      let currentPlayerEnvelope = try? await self.apiClient.authenticate(
        .init(
          deviceId: .init(rawValue: self.deviceId.id()),
          displayName: localPlayer.isAuthenticated ? localPlayer.displayName : nil,
          gameCenterLocalPlayerId: localPlayer.isAuthenticated
            ? .init(rawValue: localPlayer.gamePlayerId.rawValue)
            : nil,
          timeZone: self.timeZone.identifier
        )
      )
    else { return }

    let now = self.now.timeIntervalSinceReferenceDate
    let itsNagTime =
      Int(now - self.userDefaults.installationTime)
      >= self.serverConfig.config().upgradeInterstitial.nagBannerAfterInstallDuration
    let isFullGamePurchased =
      currentPlayerEnvelope.appleReceipt?.receipt.originalPurchaseDate != nil
    let showNagBanner = !isFullGamePurchased && itsNagTime
    try await self.modify { state in
      if !showNagBanner {
        state.nagBanner = nil
      } else if state.nagBanner == nil {
        state.nagBanner = NagBanner.State()
      }
    }

    try await withThrowingTaskGroup(of: Void.self) { group in
      group.addTask {
        guard let serverConfig = try? await self.serverConfig.refresh()
        else { return }
        let hasChangelog = serverConfig.newestBuild > self.buildNumber()
        try await self.modify { $0.hasChangelog = hasChangelog }
      }
      group.addTask {
        let dailyChallenges = try? await self.apiClient.apiRequest(
          route: .dailyChallenge(.today(language: .en)),
          as: [FetchTodaysDailyChallengeResponse].self
        )
        try await self.modify { state in
          guard let dailyChallenges else {
            state.dailyChallenges = []
            return
          }
          state.dailyChallenges = dailyChallenges
          if dailyChallenges.unlimited?.dailyChallenge.id
            != state.savedGames.dailyChallengeUnlimited?.gameContext.dailyChallenge
          {
            state.savedGames.dailyChallengeUnlimited = nil
          }
        }
      }
      group.addTask {
        guard
          let weekInReview = try? await self.apiClient.apiRequest(
            route: .leaderboard(.weekInReview(language: .en)),
            as: FetchWeekInReviewResponse.self
          )
        else { return }
        try await self.modify { $0.weekInReview = weekInReview }
      }
      group.addTask {
        try await self.loadActiveMatches()
      }
      try await group.waitForAll()
    }
  }

  private func loadActiveMatches() async throws {
    guard let response = try? await self.gameCenter.loadActiveMatches(now: self.now)
    else { return }
    try await self.modify {
      $0.hasPastTurnBasedGames = response.hasPastTurnBasedGames
      $0.turnBasedMatches = response.matches
    }
  }

  private func deleteMatch(_ matchId: TurnBasedMatch.Id) async throws {
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

    try await self.loadActiveMatches()

    await self.playSound(.uiSfxActionDestructive)
  }

  private func listenForGameCenterEvents() async throws {
    for await event in self.gameCenter.localPlayer.listener() {
      switch event {
      case .turnBased(.matchEnded),
        .turnBased(.receivedTurnEventForMatch):
        try await self.loadActiveMatches()
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
                store.send(.howToPlayButtonTapped)
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
                store: store.scope(\.activeGames),
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

      if let store = store.scope(\.nagBanner) {
        NagBannerView(store: store)
      }
    }
    .navigationBarHidden(true)
    .navigationDestination(
      item: $store.scope(\.destination).settings
    ) { store in
      SettingsView(store: store, navPresentationStyle: .navigation)
    }
    .sheet(
      item: $store.scope(\.destination).changelog
    ) { store in
      ChangelogView(store: store)
    }
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
