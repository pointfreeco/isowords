import ClientModels
import Combine
import ComposableArchitecture

extension FileClient {
  public func loadSavedGames() -> Effect<Result<SavedGamesState, NSError>, Never> {
    self.load(SavedGamesState.self, from: savedGamesFileName)
  }

  public func loadSavedGamesAsync() async throws -> SavedGamesState {
    try await self.loadAsync(SavedGamesState.self, from: savedGamesFileName)
  }

  public func saveGames(
    games: SavedGamesState, on queue: AnySchedulerOf<DispatchQueue>
  ) -> Effect<Never, Never> {
    self.save(games, to: savedGamesFileName, on: queue)
  }

  public func saveGamesAsync(games: SavedGamesState) async throws {
    try await self.saveAsync(games, to: savedGamesFileName)
  }
}

public let savedGamesFileName = "saved-games"
