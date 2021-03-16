import ComposableArchitecture
import SharedModels
import XCTestDebugSupport

extension LocalDatabaseClient {
  public static var mock: Self {
    var games: [CompletedGame] = []

    return Self(
      fetchGamesForWord: { _ in .result { .success([]) } },
      fetchStats: Effect(value: Stats()),
      fetchVocab: .none,
      migrate: .result { .success(()) },
      playedGamesCount: { _ in .init(value: 10) },
      saveGame: { game in
        .result {
          games.append(game)
          return .success(())
        }
      }
    )
  }

  #if DEBUG
    public static let failing = Self(
      fetchGamesForWord: { _ in
        .failing("\(Self.self).fetchGamesForWord is unimplemented")
      },
      fetchStats: .failing("\(Self.self).fetchStats is unimplemented"),
      fetchVocab: .failing("\(Self.self).fetchVocab is unimplemented"),
      migrate: .failing("\(Self.self).migrate is unimplemented"),
      playedGamesCount: { _ in .failing("\(Self.self).playedGamesCount is unimplemented") },
      saveGame: { _ in .failing("\(Self.self).saveGame is unimplemented") }
    )
  #endif
}
