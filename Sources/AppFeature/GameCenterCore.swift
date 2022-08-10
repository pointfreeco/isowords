import ClientModels
import ComposableArchitecture
import ComposableGameCenter
import GameFeature
import SharedModels

public enum GameCenterAction: Equatable {
  case listener(LocalPlayerClient.ListenerEvent)
  case rematchResponse(TaskResult<TurnBasedMatch>)
}

public struct GameCenterLogic: ReducerProtocol {
  @Dependency(\.apiClient) var apiClient
  @Dependency(\.database) var database
  @Dependency(\.dictionary) var dictionary
  @Dependency(\.gameCenter) var gameCenter
  @Dependency(\.mainRunLoop) var mainRunLoop

  public func reduce(
    into state: inout AppReducer.State, action: AppReducer.Action
  ) -> Effect<AppReducer.Action, Never> {
    switch action {
    case .appDelegate(.didFinishLaunching):
      return .run { send in
        try await self.gameCenter.localPlayer.authenticate()
        for await event in self.gameCenter.localPlayer.listener() {
          await send(.gameCenter(.listener(event)))
        }
      }

    case .currentGame(.game(.gameOver(.rematchButtonTapped))):
      guard
        let game = state.game,
        let turnBasedMatch = game.turnBasedContext
      else { return .none }

      state.game = nil

      return .task {
        await .gameCenter(
          .rematchResponse(
            TaskResult {
              try await self.gameCenter.turnBasedMatch.rematch(
                turnBasedMatch.match.matchId
              )
            }
          )
        )
      }

    case let .gameCenter(.listener(.turnBased(.matchEnded(match)))):
      guard
        state.game?.turnBasedContext?.match.matchId == match.matchId,
        let turnBasedMatchData = match.matchData?.turnBasedMatchData
      else { return .none }

      let newGame = Game.State(
        gameCurrentTime: self.mainRunLoop.now.date,
        localPlayer: self.gameCenter.localPlayer.localPlayer(),
        turnBasedMatch: match,
        turnBasedMatchData: turnBasedMatchData
      )
      state.game = newGame

      return .fireAndForget {
        try await self.database.saveGame(.init(gameState: newGame))
      }

    case let .gameCenter(
      .listener(.turnBased(.receivedTurnEventForMatch(match, didBecomeActive)))):
      return handleTurnBasedMatch(match, state: &state, didBecomeActive: didBecomeActive)

    case let .gameCenter(.listener(.turnBased(.wantsToQuitMatch(match)))):
      return .fireAndForget {
        try await self.gameCenter.turnBasedMatch.endMatchInTurn(
          .init(
            for: match.matchId,
            matchData: match.matchData ?? Data(),
            localPlayerId: self.gameCenter.localPlayer.localPlayer().gamePlayerId,
            localPlayerMatchOutcome: .quit,
            message: """
              \(self.gameCenter.localPlayer.localPlayer().displayName) \
              forfeited the match.
              """
          )
        )
      }
      
    case .gameCenter(.listener):
      return .none
      
    case let .gameCenter(.rematchResponse(.success(turnBasedMatch))),
      let .home(
        .destination(
          .presented(
            .multiplayer(
              .destination(.pastGames(.pastGame(_, .delegate(.openMatch(turnBasedMatch)))))
            )
          )
        )
      ):
      return handleTurnBasedMatch(turnBasedMatch, state: &state, didBecomeActive: true)

    case let .home(.activeGames(.turnBasedGameMenuItemTapped(.rematch(matchId)))):
      return .task {
        await .gameCenter(
          .rematchResponse(
            TaskResult {
              try await self.gameCenter.turnBasedMatch.rematch(matchId)
            }
          )
        )
      }

    default:
      return .none
    }
  }

  private func handleTurnBasedMatch(
    _ match: TurnBasedMatch,
    state: inout AppReducer.State,
    didBecomeActive: Bool
  ) -> Effect<AppReducer.Action, Never> {
    guard let matchData = match.matchData, !matchData.isEmpty else {
      let context = TurnBasedContext(
        localPlayer: self.gameCenter.localPlayer.localPlayer(),
        match: match,
        metadata: .init(
          lastOpenedAt: self.mainRunLoop.now.date,
          playerIndexToId: [:]
        )
      )
      let game = Game.State(
        cubes: self.dictionary.randomCubes(.en),
        gameContext: .turnBased(context),
        gameCurrentTime: self.mainRunLoop.now.date,
        gameMode: .unlimited,
        gameStartTime: match.creationDate
      )
      state.currentGame = .init(
        game: game,
        settings: state.home.settings
      )
      return .fireAndForget {
        await self.gameCenter.turnBasedMatchmakerViewController.dismiss()
        try await self.gameCenter.turnBasedMatch.saveCurrentTurn(
          match.matchId,
          Data(
            turnBasedMatchData: .init(
              context: context,
              gameState: game,
              playerId: self.apiClient.currentPlayer()?.player.id
            )
          )
        )
      }
    }

    guard let turnBasedMatchData = matchData.turnBasedMatchData else {
      return .none
    }

    if didBecomeActive {
      var gameState = Game.State(
        gameCurrentTime: self.mainRunLoop.now.date,
        localPlayer: self.gameCenter.localPlayer.localPlayer(),
        turnBasedMatch: match,
        turnBasedMatchData: turnBasedMatchData
      )
      gameState.activeGames = state.currentGame.game?.activeGames ?? .init()
      gameState.isGameLoaded = state.game != nil
      // TODO: Reuse game logic
      var isGameOver: Bool {
        match.participants.contains(where: { $0.matchOutcome != .none })
      }
      if match.status == .ended || isGameOver {
        gameState.gameOver = .init(
          completedGame: CompletedGame(gameState: gameState),
          isDemo: gameState.isDemo,
          turnBasedContext: gameState.turnBasedContext
        )
      }
      state.currentGame = .init(
        game: gameState,
        settings: state.home.settings
      )
      return .fireAndForget { [isYourTurn = gameState.isYourTurn, turnBasedMatchData] in
        await self.gameCenter.turnBasedMatchmakerViewController.dismiss()
        if isYourTurn {
          var turnBasedMatchData = turnBasedMatchData
          turnBasedMatchData.metadata.lastOpenedAt = self.mainRunLoop.now.date
          try await self.gameCenter.turnBasedMatch.saveCurrentTurn(
            match.matchId,
            Data(turnBasedMatchData: turnBasedMatchData)
          )
        }
      }
    }

    let context = TurnBasedContext(
      localPlayer: self.gameCenter.localPlayer.localPlayer(),
      match: match,
      metadata: turnBasedMatchData.metadata
    )
    guard
      state.game?.turnBasedContext?.match.matchId != match.matchId,
      context.currentParticipantIsLocalPlayer,
      match.participants.allSatisfy({ $0.matchOutcome == .none }),
      let lastTurnDate = match.participants.compactMap(\.lastTurnDate).max(),
      lastTurnDate > self.mainRunLoop.now.date.addingTimeInterval(-60)
    else { return .none }

    return .fireAndForget {
      await self.gameCenter.showNotificationBanner(
        .init(title: match.message, message: nil)
      )
    }
  }
}
