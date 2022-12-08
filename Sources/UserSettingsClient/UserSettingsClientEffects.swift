import ClientModels

extension UserSettingsClient {
  public func loadSavedGames() async throws -> SavedGamesState {
    try await self.load(SavedGamesState.self, from: savedGamesKey)
  }

  public func save(games: SavedGamesState) async throws {
    try await self.save(games, to: savedGamesKey)
  }
}

public let savedGamesKey = "saved-games"
