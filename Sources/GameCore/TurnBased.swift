import ClientModels
import ComposableArchitecture
import GameOverFeature
import SharedModels

struct TurnBasedLogic: ReducerProtocol {
  @Dependency(\.apiClient) var apiClient
  @Dependency(\.database) var database
  @Dependency(\.feedbackGenerator) var feedbackGenerator
  @Dependency(\.gameCenter) var gameCenter
  @Dependency(\.mainRunLoop) var mainRunLoop

  func reduce(into state: inout Game.State, action: Game.Action) -> Effect<Game.Action, Never> {
    guard let turnBasedContext = state.turnBasedContext
    else { return .none }

    switch action {
    case let .gameCenter(.listener(.turnBased(.receivedTurnEventForMatch(match, _)))),
      let .gameCenter(.listener(.turnBased(.matchEnded(match)))):

      guard turnBasedContext.match.matchId == match.matchId
      else { return .none }

      guard let turnBasedMatchData = match.matchData?.turnBasedMatchData
      else { return .none }

      state = Game.State(
        gameCurrentTime: self.mainRunLoop.now.date,
        localPlayer: turnBasedContext.localPlayer,
        turnBasedMatch: match,
        turnBasedMatchData: turnBasedMatchData
      )
      state.isGameLoaded = true

      guard
        match.status != .ended,
        match.participants.allSatisfy({ $0.matchOutcome == .none })
      else {
        state.gameOver = .init(
          completedGame: CompletedGame(gameState: state),
          isDemo: state.isDemo,
          turnBasedContext: state.turnBasedContext
        )
        return .fireAndForget {
          await self.feedbackGenerator.selectionChanged()
          try await self.gameCenter.turnBasedMatch.remove(match)
        }
      }

      return .fireAndForget { await self.feedbackGenerator.selectionChanged() }

    case let .gameCenter(.turnBasedMatchResponse(.success(match))):
      guard
        let turnBasedMatchData = match.matchData?.turnBasedMatchData
      else { return .none }

      var gameState = Game.State(
        gameCurrentTime: self.mainRunLoop.now.date,
        localPlayer: self.gameCenter.localPlayer.localPlayer(),
        turnBasedMatch: match,
        turnBasedMatchData: turnBasedMatchData
      )
      gameState.activeGames = state.activeGames
      gameState.isGameLoaded = state.isGameLoaded
      state = gameState
      return .none

    case .gameCenter(.turnBasedMatchResponse(.failure)):
      return .none

    case .gameOver(.delegate(.close)),
      .exitButtonTapped:
      return .none

    case .task:
      return .run { send in
        for await event in self.gameCenter.localPlayer.listener() {
          await send(.gameCenter(.listener(event)))
        }
      }

    case .submitButtonTapped,
      .wordSubmitButton(.delegate(.confirmSubmit)),
      .confirmRemoveCube:
      guard
        let move = state.moves.last,
        let localPlayerIndex = turnBasedContext.localPlayerIndex,
        localPlayerIndex == move.playerIndex
      else { return .none }

      let turnBasedMatchData = TurnBasedMatchData(
        context: turnBasedContext,
        gameState: state,
        playerId: self.apiClient.currentPlayer()?.player.id
      )
      let matchData = Data(turnBasedMatchData: turnBasedMatchData)

      return .task { [state] in
        return await .gameCenter(
          .turnBasedMatchResponse(
            TaskResult {
              if state.isGameOver {
                let completedGame = CompletedGame(gameState: state)
                if
                  let completedMatch = CompletedMatch(
                    completedGame: completedGame,
                    turnBasedContext: turnBasedContext
                  )
                {
                  try await self.gameCenter.turnBasedMatch.endMatchInTurn(
                    .init(
                      for: turnBasedContext.match.matchId,
                      matchData: matchData,
                      localPlayerId: turnBasedContext.localPlayer.gamePlayerId,
                      localPlayerMatchOutcome: completedMatch.yourOutcome,
                      message: "Game over! Let’s see how you did!"
                    )
                  )
                  try await self.database.saveGame(completedGame)
                }
              } else {
                switch move.type {
                case .removedCube:
                  let shouldEndTurn =
                    state.moves.count > 1
                    && state.moves[state.moves.count - 2].playerIndex
                      == turnBasedContext.localPlayerIndex

                  if shouldEndTurn {
                    try await self.gameCenter.turnBasedMatch.endTurn(
                      .init(
                        for: turnBasedContext.match.matchId,
                        matchData: matchData,
                        message: "\(turnBasedContext.localPlayer.displayName) removed cubes!"
                      )
                    )
                  } else {
                    try await self.gameCenter.turnBasedMatch
                      .saveCurrentTurn(turnBasedContext.match.matchId, matchData)
                  }

                case let .playedWord(cubeFaces):
                  let word = state.cubes.string(from: cubeFaces)
                  let score = SharedModels.score(word)
                  let reaction = (move.reactions?.values.first).map { " \($0.rawValue)" } ?? ""

                  try await self.gameCenter.turnBasedMatch.endTurn(
                    .init(
                      for: turnBasedContext.match.matchId,
                      matchData: matchData,
                      message: """
                        \(turnBasedContext.localPlayer.displayName) played \(word)! \
                        (+\(score)\(reaction))
                        """
                    )
                  )
                }
              }
              return try await self.gameCenter.turnBasedMatch.load(turnBasedContext.match.matchId)
            }
          )
        )
      }
    default:
      return .none
    }
  }
}

extension ReducerProtocol where State == Game.State, Action == Game.Action {
  func filterActionsForYourTurn() -> some ReducerProtocol<State, Action> {
    self.filter { state, action in
      switch action {
      case .pan,
        .submitButtonTapped,
        .tap,
        .wordSubmitButton(.delegate(.confirmSubmit)):
        return state.isYourTurn

      case .activeGames,
        .alert,
        .cancelButtonTapped,
        .confirmRemoveCube,
        .delayedShowUpgradeInterstitial,
        .dismissBottomMenu,
        .doubleTap,
        .endGameButtonTapped,
        .exitButtonTapped,
        .forfeitGameButtonTapped,
        .gameCenter,
        .gameLoaded,
        .gameOver,
        .lowPowerModeChanged,
        .matchesLoaded,
        .menuButtonTapped,
        .task,
        .savedGamesLoaded,
        .settingsButtonTapped,
        .timerTick,
        .trayButtonTapped,
        .upgradeInterstitial,
        .wordSubmitButton:
        return true
      }
    }
  }
}
