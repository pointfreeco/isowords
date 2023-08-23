import ComposableArchitecture
import SharedModels
import XCTestDynamicOverlay

extension DependencyValues {
  public var database: LocalDatabaseClient {
    get { self[LocalDatabaseClient.self] }
    set { self[LocalDatabaseClient.self] = newValue }
  }
}

extension LocalDatabaseClient: TestDependencyKey {
  public static let previewValue = Self.mock

  public static let testValue = Self(
    fetchGamesForWord: unimplemented("\(Self.self).fetchGamesForWord"),
    fetchStats: unimplemented("\(Self.self).fetchStats"),
    fetchVocab: unimplemented("\(Self.self).fetchVocab"),
    migrate: unimplemented("\(Self.self).migrate"),
    playedGamesCount: unimplemented("\(Self.self).playedGamesCount"),
    saveGame: unimplemented("\(Self.self).saveGame")
  )
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
