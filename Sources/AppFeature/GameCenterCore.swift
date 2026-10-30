import ClientModels
import ComposableArchitecture
import ComposableGameCenter
import Dependencies
import Foundation
import GameCore
import GameOverFeature
import SharedModels
import SwiftUI

extension AppReducer {
  @MainActor
  func listenForGameCenterEvents() async throws {
    try await gameCenter.localPlayer.authenticate()
    for await event in gameCenter.localPlayer.listener() {
      switch event {
      case let .turnBased(.matchEnded(match)):
        try await matchEnded(match)

      case let .turnBased(.receivedTurnEventForMatch(match, didBecomeActive)):
        try await handleTurnBasedMatch(match, didBecomeActive: didBecomeActive)

      case let .turnBased(.wantsToQuitMatch(match)):
        try? await gameCenter.turnBasedMatch.endMatchInTurn(
          .init(
            for: match.matchId,
            matchData: match.matchData ?? Data(),
            localPlayerId: gameCenter.localPlayer.localPlayer().gamePlayerId,
            localPlayerMatchOutcome: .quit,
            message: """
              \(gameCenter.localPlayer.localPlayer().displayName) \
              forfeited the match.
              """
          )
        )

      default:
        break
      }
    }
  }

  @MainActor
  func openTurnBasedMatch(id matchId: TurnBasedMatch.Id) async throws {
    guard let match = try? await gameCenter.turnBasedMatch.load(matchId)
    else { return }
    try await handleTurnBasedMatch(match, didBecomeActive: true, animation: .default)
  }

  @MainActor
  func rematch(_ matchId: TurnBasedMatch.Id) async throws {
    guard let match = try? await gameCenter.turnBasedMatch.rematch(matchId)
    else { return }
    try await handleTurnBasedMatch(match, didBecomeActive: true)
  }

  @MainActor
  private func matchEnded(_ match: TurnBasedMatch) async throws {
    guard
      case let .game(game) = store.destination,
      game.gameContext.turnBased?.match.matchId == match.matchId,
      let turnBasedMatchData = match.matchData?.turnBasedMatchData
    else { return }

    let newGame = Game.State(
      gameCurrentTime: now,
      localPlayer: gameCenter.localPlayer.localPlayer(),
      turnBasedMatch: match,
      turnBasedMatchData: turnBasedMatchData
    )
    try store.modify { $0.destination = .game(newGame) }
    try? await saveGame(.init(gameState: newGame))
  }

  @MainActor
  func handleTurnBasedMatch(
    _ match: TurnBasedMatch,
    didBecomeActive: Bool,
    animation: Animation? = nil
  ) async throws {
    guard let matchData = match.matchData, !matchData.isEmpty else {
      let context = TurnBasedContext(
        localPlayer: gameCenter.localPlayer.localPlayer(),
        match: match,
        metadata: .init(
          lastOpenedAt: now,
          playerIndexToId: [:]
        )
      )
      let game = Game.State(
        cubes: randomCubes(.en),
        gameContext: .turnBased(context),
        gameCurrentTime: now,
        gameMode: .unlimited,
        gameStartTime: match.creationDate
      )
      try withAnimation(animation) {
        _ = try store.modify { $0.destination = .game(game) }
      }
      await gameCenter.turnBasedMatchmakerViewController.dismiss()
      try? await gameCenter.turnBasedMatch.saveCurrentTurn(
        match.matchId,
        Data(
          turnBasedMatchData: .init(
            context: context,
            gameState: game,
            playerId: currentPlayer()?.player.id
          )
        )
      )
      return
    }

    guard let turnBasedMatchData = matchData.turnBasedMatchData else { return }

    if didBecomeActive {
      var gameState = Game.State(
        gameCurrentTime: now,
        localPlayer: gameCenter.localPlayer.localPlayer(),
        turnBasedMatch: match,
        turnBasedMatchData: turnBasedMatchData
      )
      let game = store.destination?.game
      gameState.activeGames = game?.activeGames ?? .init()
      gameState.isGameLoaded = game != nil
      // TODO: Reuse game logic
      var isGameOver: Bool {
        match.participants.contains(where: { $0.matchOutcome != .none })
      }
      if match.status == .ended || isGameOver {
        gameState.destination = .gameOver(
          GameOver.State(
            completedGame: CompletedGame(gameState: gameState),
            isDemo: gameState.isDemo,
            turnBasedContext: gameState.gameContext.turnBased
          )
        )
      }
      try withAnimation(animation) {
        _ = try store.modify { [gameState] in $0.destination = .game(gameState) }
      }
      await gameCenter.turnBasedMatchmakerViewController.dismiss()
      if gameState.isYourTurn {
        var turnBasedMatchData = turnBasedMatchData
        turnBasedMatchData.metadata.lastOpenedAt = now
        try? await gameCenter.turnBasedMatch.saveCurrentTurn(
          match.matchId,
          Data(turnBasedMatchData: turnBasedMatchData)
        )
      }
      return
    }

    let context = TurnBasedContext(
      localPlayer: gameCenter.localPlayer.localPlayer(),
      match: match,
      metadata: turnBasedMatchData.metadata
    )
    guard
      store.destination?.game?.gameContext.turnBased?.match.matchId != match.matchId,
      context.currentParticipantIsLocalPlayer,
      match.participants.allSatisfy({ $0.matchOutcome == .none }),
      let lastTurnDate = match.participants.compactMap(\.lastTurnDate).max(),
      lastTurnDate > now.addingTimeInterval(-60)
    else { return }

    await gameCenter.showNotificationBanner(
      .init(title: match.message, message: nil)
    )
  }
}
