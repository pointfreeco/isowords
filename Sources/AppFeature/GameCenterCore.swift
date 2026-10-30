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
    try await self.gameCenter.localPlayer.authenticate()
    for await event in self.gameCenter.localPlayer.listener() {
      switch event {
      case let .turnBased(.matchEnded(match)):
        try await self.matchEnded(match)

      case let .turnBased(.receivedTurnEventForMatch(match, didBecomeActive)):
        try await self.handleTurnBasedMatch(match, didBecomeActive: didBecomeActive)

      case let .turnBased(.wantsToQuitMatch(match)):
        try? await self.gameCenter.turnBasedMatch.endMatchInTurn(
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

      default:
        break
      }
    }
  }

  @MainActor
  func openTurnBasedMatch(id matchId: TurnBasedMatch.Id) async throws {
    guard let match = try? await self.gameCenter.turnBasedMatch.load(matchId)
    else { return }
    try await self.handleTurnBasedMatch(match, didBecomeActive: true, animation: .default)
  }

  @MainActor
  func rematch(_ matchId: TurnBasedMatch.Id) async throws {
    guard let match = try? await self.gameCenter.turnBasedMatch.rematch(matchId)
    else { return }
    try await self.handleTurnBasedMatch(match, didBecomeActive: true)
  }

  @MainActor
  private func matchEnded(_ match: TurnBasedMatch) async throws {
    guard
      case let .game(game) = store.destination,
      game.gameContext.turnBased?.match.matchId == match.matchId,
      let turnBasedMatchData = match.matchData?.turnBasedMatchData
    else { return }

    let newGame = Game.State(
      gameCurrentTime: self.now,
      localPlayer: self.gameCenter.localPlayer.localPlayer(),
      turnBasedMatch: match,
      turnBasedMatchData: turnBasedMatchData
    )
    try store.modify { $0.destination = .game(newGame) }
    try? await self.saveGame(.init(gameState: newGame))
  }

  @MainActor
  func handleTurnBasedMatch(
    _ match: TurnBasedMatch,
    didBecomeActive: Bool,
    animation: Animation? = nil
  ) async throws {
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
      try withAnimation(animation) {
        _ = try store.modify { $0.destination = .game(game) }
      }
      await self.gameCenter.turnBasedMatchmakerViewController.dismiss()
      try? await self.gameCenter.turnBasedMatch.saveCurrentTurn(
        match.matchId,
        Data(
          turnBasedMatchData: .init(
            context: context,
            gameState: game,
            playerId: self.currentPlayer()?.player.id
          )
        )
      )
      return
    }

    guard let turnBasedMatchData = matchData.turnBasedMatchData else { return }

    if didBecomeActive {
      var gameState = Game.State(
        gameCurrentTime: self.now,
        localPlayer: self.gameCenter.localPlayer.localPlayer(),
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
      await self.gameCenter.turnBasedMatchmakerViewController.dismiss()
      if gameState.isYourTurn {
        var turnBasedMatchData = turnBasedMatchData
        turnBasedMatchData.metadata.lastOpenedAt = self.now
        try? await self.gameCenter.turnBasedMatch.saveCurrentTurn(
          match.matchId,
          Data(turnBasedMatchData: turnBasedMatchData)
        )
      }
      return
    }

    let context = TurnBasedContext(
      localPlayer: self.gameCenter.localPlayer.localPlayer(),
      match: match,
      metadata: turnBasedMatchData.metadata
    )
    guard
      store.destination?.game?.gameContext.turnBased?.match.matchId != match.matchId,
      context.currentParticipantIsLocalPlayer,
      match.participants.allSatisfy({ $0.matchOutcome == .none }),
      let lastTurnDate = match.participants.compactMap(\.lastTurnDate).max(),
      lastTurnDate > self.now.addingTimeInterval(-60)
    else { return }

    await self.gameCenter.showNotificationBanner(
      .init(title: match.message, message: nil)
    )
  }
}
