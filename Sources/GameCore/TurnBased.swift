import ClientModels
import ComposableArchitecture
import ComposableGameCenter
import Dependencies
import Foundation
import GameOverFeature
import SharedModels

extension Game {
  func turnBased(state: inout State, action: Action) {
    guard let turnBasedContext = state.gameContext.turnBased
    else { return }

    switch action {
    case .submitButtonTapped,
      .confirmRemoveCube,
      .destination(.bottomMenu(.confirmRemoveCube)):
      guard
        let move = state.moves.last,
        let localPlayerIndex = turnBasedContext.localPlayerIndex,
        localPlayerIndex == move.playerIndex
      else { return }

      let turnBasedMatchData = TurnBasedMatchData(
        context: turnBasedContext,
        gameState: state,
        playerId: apiClient.currentPlayer()?.player.id
      )
      let matchData = Data(turnBasedMatchData: turnBasedMatchData)
      let isGameOver = state.isGameOver || state.isOutOfTimeOrCubes

      store.addTask { [state] in
        let match: TurnBasedMatch
        do {
          if isGameOver {
            let completedGame = CompletedGame(gameState: state)
            if let completedMatch = CompletedMatch(
              completedGame: completedGame,
              turnBasedContext: turnBasedContext
            ) {
              try await gameCenter.turnBasedMatch.endMatchInTurn(
                .init(
                  for: turnBasedContext.match.matchId,
                  matchData: matchData,
                  localPlayerId: turnBasedContext.localPlayer.gamePlayerId,
                  localPlayerMatchOutcome: completedMatch.yourOutcome,
                  message: "Game over! Let’s see how you did!"
                )
              )
              try await saveGame(completedGame)
            }
          } else {
            switch move.type {
            case .removedCube:
              let shouldEndTurn =
                state.moves.count > 1
                && state.moves[state.moves.count - 2].playerIndex
                  == turnBasedContext.localPlayerIndex

              if shouldEndTurn {
                try await gameCenter.turnBasedMatch.endTurn(
                  .init(
                    for: turnBasedContext.match.matchId,
                    matchData: matchData,
                    message: "\(turnBasedContext.localPlayer.displayName) removed cubes!"
                  )
                )
              } else {
                try await gameCenter.turnBasedMatch
                  .saveCurrentTurn(turnBasedContext.match.matchId, matchData)
              }

            case let .playedWord(cubeFaces):
              let word = state.cubes.string(from: cubeFaces)
              let score = SharedModels.score(word)
              let reaction = (move.reactions?.values.first).map { " \($0.rawValue)" } ?? ""

              try await gameCenter.turnBasedMatch.endTurn(
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
          match = try await gameCenter.turnBasedMatch.load(turnBasedContext.match.matchId)
        } catch {
          return
        }
        guard let turnBasedMatchData = match.matchData?.turnBasedMatchData
        else { return }
        let localPlayer = gameCenter.localPlayer.localPlayer()
        let now = now
        try store.modify { state in
          var gameState = Game.State(
            gameCurrentTime: now,
            localPlayer: localPlayer,
            turnBasedMatch: match,
            turnBasedMatchData: turnBasedMatchData
          )
          gameState.activeGames = state.activeGames
          gameState.isGameLoaded = state.isGameLoaded
          if state.isGameOver {
            gameState.destination = state.destination
          }
          state = gameState
        }
      }

    default:
      break
    }
  }

  func mountTurnBased() {
    store.addTask {
      for await event in gameCenter.localPlayer.listener() {
        let match: TurnBasedMatch
        switch event {
        case let .turnBased(.receivedTurnEventForMatch(turnBasedMatch, _)),
          let .turnBased(.matchEnded(turnBasedMatch)):
          match = turnBasedMatch
        default:
          continue
        }
        var isMatchOver: Bool?
        try store.modify { isMatchOver = $0.receive(turnBasedMatch: match, now: now) }
        guard let isMatchOver else { continue }
        await feedbackGenerator.selectionChanged()
        if isMatchOver {
          try? await gameCenter.turnBasedMatch.remove(match)
        }
      }
    }
  }
}

extension Game.State {
  fileprivate mutating func receive(turnBasedMatch match: TurnBasedMatch, now: Date) -> Bool? {
    guard
      let turnBasedContext = gameContext.turnBased,
      turnBasedContext.match.matchId == match.matchId,
      let turnBasedMatchData = match.matchData?.turnBasedMatchData
    else { return nil }

    self = Game.State(
      gameCurrentTime: now,
      localPlayer: turnBasedContext.localPlayer,
      turnBasedMatch: match,
      turnBasedMatchData: turnBasedMatchData
    )
    isGameLoaded = true

    guard
      match.status != .ended,
      match.participants.allSatisfy({ $0.matchOutcome == .none })
    else {
      destination = .gameOver(
        GameOver.State(
          completedGame: CompletedGame(gameState: self),
          isDemo: isDemo,
          turnBasedContext: gameContext.turnBased
        )
      )
      return true
    }
    return false
  }
}
