import ClientModels
import ComposableArchitecture
import ComposableGameCenter
import Foundation
import GameFeature
import SharedModels

public enum GameCenterAction: Equatable {
  case listener(LocalPlayerClient.ListenerEvent)
  case rematchResponse(TaskResult<TurnBasedMatch>)
}

public struct GameCenterLogic: Reducer {
  @Dependency(\.apiClient.currentPlayer) var currentPlayer
  @Dependency(\.gameCenter) var gameCenter
  @Dependency(\.mainRunLoop.now.date) var now
  @Dependency(\.dictionary.randomCubes) var randomCubes
  @Dependency(\.database.saveGame) var saveGame

  public var body: some ReducerOf<AppReducer> {
    Reduce { state, action in
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

        return .run { send in
          await send(
            .gameCenter(
              .rematchResponse(
                TaskResult {
                  try await self.gameCenter.turnBasedMatch.rematch(
                    turnBasedMatch.match.matchId
                  )
                }
              )
            )
          )
        }

      case let .gameCenter(.listener(.turnBased(.matchEnded(match)))):
        guard
          state.game?.turnBasedContext?.match.matchId == match.matchId,
          let turnBasedMatchData = match.matchData?.turnBasedMatchData
        else { return .none }

        let newGame = Game.State(
          gameCurrentTime: self.now,
          localPlayer: self.gameCenter.localPlayer.localPlayer(),
          turnBasedMatch: match,
          turnBasedMatchData: turnBasedMatchData
        )
        state.game = newGame

        return .run { _ in
          try await self.saveGame(.init(gameState: newGame))
        }

      case let .gameCenter(
        .listener(.turnBased(.receivedTurnEventForMatch(match, didBecomeActive)))):
        return handleTurnBasedMatch(match, state: &state, didBecomeActive: didBecomeActive)

      case let .gameCenter(.listener(.turnBased(.wantsToQuitMatch(match)))):
        return .run { _ in
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
            .multiplayer(
              .destination(.pastGames(.pastGame(_, .delegate(.openMatch(turnBasedMatch)))))
            )
          )
        ):
        return handleTurnBasedMatch(turnBasedMatch, state: &state, didBecomeActive: true)

      case let .home(.activeGames(.turnBasedGameMenuItemTapped(.rematch(matchId)))):
        return .run { send in
          await send(
            .gameCenter(
              .rematchResponse(
                TaskResult {
                  try await self.gameCenter.turnBasedMatch.rematch(matchId)
                }
              )
            )
          )
        }

      default:
        return .none
      }
    }
  }

  private func handleTurnBasedMatch(
    _ match: TurnBasedMatch,
    state: inout AppReducer.State,
    didBecomeActive: Bool
  ) -> EffectOf<AppReducer> {
    guard let matchData = match.matchData, !matchData.isEmpty else {
      let context = TurnBasedContext(
        localPlayer: self.gameCenter.localPlayer.localPlayer(),
        match: match,
        metadata: .init(
          lastOpenedAt: self.now,
          playerIndexToId: [:]
        )
      )
      let game = Game.State(
        cubes: self.randomCubes(.en),
        gameContext: .turnBased(context),
        gameCurrentTime: self.now,
        gameMode: .unlimited,
        gameStartTime: match.creationDate
      )
      state.currentGame = .init(
        game: game,
        settings: state.home.settings
      )
      return .run { _ in
        await self.gameCenter.turnBasedMatchmakerViewController.dismiss()
        try await self.gameCenter.turnBasedMatch.saveCurrentTurn(
          match.matchId,
          Data(
            turnBasedMatchData: .init(
              context: context,
              gameState: game,
              playerId: self.currentPlayer()?.player.id
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
        gameCurrentTime: self.now,
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
      return .run { [isYourTurn = gameState.isYourTurn, turnBasedMatchData] _ in
        await self.gameCenter.turnBasedMatchmakerViewController.dismiss()
        if isYourTurn {
          var turnBasedMatchData = turnBasedMatchData
          turnBasedMatchData.metadata.lastOpenedAt = self.now
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
      lastTurnDate > self.now.addingTimeInterval(-60)
    else { return .none }

    return .run { _ in
      await self.gameCenter.showNotificationBanner(
        .init(title: match.message, message: nil)
      )
    }
  }
}
