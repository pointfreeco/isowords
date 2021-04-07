import ActiveGamesFeature
import ClientModels
import ComposableArchitecture
import Foundation
import GameOverFeature
import SharedModels

extension InProgressGame {
  public init(gameState: GameState) {
    self.init(
      cubes: ArchivablePuzzle(cubes: gameState.cubes),
      gameContext: gameState.gameContext,
      gameMode: gameState.gameMode,
      gameStartTime: gameState.gameStartTime,
      language: gameState.language,
      moves: gameState.moves,
      secondsPlayed: gameState.secondsPlayed
    )
  }
}

extension GameState {
  public init(inProgressGame: InProgressGame) {
    self.init(
      archivableCubes: inProgressGame.cubes,
      gameContext: inProgressGame.gameContext,
      // TODO: inject gameCurrentTime from the outside
      gameCurrentTime: inProgressGame.gameStartTime,
      gameMode: inProgressGame.gameMode,
      gameStartTime: inProgressGame.gameStartTime,
      language: inProgressGame.language,
      moves: inProgressGame.moves,
      secondsPlayed: inProgressGame.secondsPlayed
    )
  }

  // TODO: where is this used?
  public init(
    completedGame: CompletedGame,
    gameCurrentTime: Date,
    gameStartTime: Date
  ) {
    self.init(
      archivableCubes: completedGame.cubes,
      gameContext: .solo,
      gameCurrentTime: gameCurrentTime,
      gameMode: completedGame.gameMode,
      gameStartTime: gameStartTime,
      language: completedGame.language,
      secondsPlayed: completedGame.secondsPlayed
    )
  }
}
