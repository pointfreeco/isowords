import ClientModels
import Combine
import ComposableArchitecture

extension FileClient {
  public func loadSavedGames() -> Effect<Result<SavedGamesState, NSError>, Never> {
    self.load(SavedGamesState.self, from: savedGamesFileName)
  }

  public func saveGames(
    games: SavedGamesState, on queue: AnySchedulerOf<DispatchQueue>
  ) -> Effect<Never, Never> {
    self.save(games, to: savedGamesFileName, on: queue)
  }
}

public let savedGamesFileName = "saved-games"
