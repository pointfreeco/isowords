import ComposableArchitecture
import SharedModels

extension DependencyValues {
  public var database: LocalDatabaseClient {
    get { self[LocalDatabaseClient.self] }
    set { self[LocalDatabaseClient.self] = newValue }
  }
}

extension LocalDatabaseClient: TestDependencyKey {
  public static let previewValue = Self.mock
  public static let testValue = Self()
}

extension LocalDatabaseClient {
  public static var mock: Self {
    let games = ActorIsolated<[CompletedGame]>([])

    return Self(
      fetchGamesForWord: { _ in [] },
      fetchStats: { Stats() },
      fetchVocab: { Vocab(words: []) },
      migrate: {},
      playedGamesCount: { _ in 10 },
      saveGame: { game in await games.withValue { $0.append(game) } }
    )
  }
}
