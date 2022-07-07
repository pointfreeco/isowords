import ComposableArchitecture
import SharedModels
import XCTestDynamicOverlay

extension LocalDatabaseClient {
  public static var mock: Self {
    let games = UncheckedSendable(wrappedValue: Box(wrappedValue: [CompletedGame]()))

    return Self(
      fetchGamesForWord: { _ in .result { .success([]) } },
      fetchGamesForWordAsync: { _ in [] },
      fetchStats: Effect(value: Stats()),
      fetchStatsAsync: { Stats() },
      fetchVocab: .none,
      fetchVocabAsync: { Vocab(words: []) },
      migrate: .result { .success(()) },
      migrateAsync: {},
      playedGamesCount: { _ in .init(value: 10) },
      playedGamesCountAsync: { _ in 10 },
      saveGame: { game in
        .result {
          games.uncheckedValue.boxedValue.append(game)
          return .success(())
        }
      },
      saveGameAsync: {
        games.uncheckedValue.boxedValue.append($0)
      }
    )
  }

  #if DEBUG
    public static let failing = Self(
      fetchGamesForWord: { _ in
        .failing("\(Self.self).fetchGamesForWord is unimplemented")
      },
      fetchGamesForWordAsync: XCTUnimplemented("\(Self.self).fetchGamesForWordAsync"),
      fetchStats: .failing("\(Self.self).fetchStats is unimplemented"),
      fetchStatsAsync: XCTUnimplemented("\(Self.self).fetchStatsAsync"),
      fetchVocab: .failing("\(Self.self).fetchVocab is unimplemented"),
      fetchVocabAsync: XCTUnimplemented("\(Self.self).fetchVocabAsync"),
      migrate: .failing("\(Self.self).migrate is unimplemented"),
      migrateAsync: XCTUnimplemented("\(Self.self).migrateAsync"),
      playedGamesCount: { _ in .failing("\(Self.self).playedGamesCount is unimplemented") },
      playedGamesCountAsync: XCTUnimplemented("\(Self.self).playedGamesCountAsync"),
      saveGame: { _ in .failing("\(Self.self).saveGame is unimplemented") },
      saveGameAsync: XCTUnimplemented("\(Self.self).saveGameAsync")
    )
  #endif
}
