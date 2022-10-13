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
    fetchGamesForWord: XCTUnimplemented("\(Self.self).fetchGamesForWord"),
    fetchStats: XCTUnimplemented("\(Self.self).fetchStats"),
    fetchVocab: XCTUnimplemented("\(Self.self).fetchVocab"),
    migrate: XCTUnimplemented("\(Self.self).migrate"),
    playedGamesCount: XCTUnimplemented("\(Self.self).playedGamesCount"),
    saveGame: XCTUnimplemented("\(Self.self).saveGame")
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
