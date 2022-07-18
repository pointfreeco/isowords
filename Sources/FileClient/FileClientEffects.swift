import ClientModels
import Combine
import ComposableArchitecture

extension FileClient {
  public func loadSavedGames() async throws -> SavedGamesState {
    try await self.loadAsync(SavedGamesState.self, from: savedGamesFileName)
  }

  public func save(games: SavedGamesState) async throws {
    try await self.saveAsync(games, to: savedGamesFileName)
  }
}

public let savedGamesFileName = "saved-games"
