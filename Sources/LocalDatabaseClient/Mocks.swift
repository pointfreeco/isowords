import ComposableArchitecture
import SharedModels
import XCTestDynamicOverlay

class Box<Value> {
  var wrappedValue: Value
  init(wrappedValue: Value) {
    self.wrappedValue = wrappedValue
  }
}

extension LocalDatabaseClient {
  public static var mock: Self {
    let games = UncheckedSendable(wrappedValue: Box(wrappedValue: [CompletedGame]()))

    return Self(
      fetchGamesForWord: { _ in [] },
      fetchStats: { Stats() },
      fetchVocab: { Vocab(words: []) },
      migrate: {},
      playedGamesCount: { _ in 10 },
      saveGame: { games.uncheckedValue.wrappedValue.append($0) }
    )
  }

  #if DEBUG
    public static let failing = Self(
      fetchGamesForWord: XCTUnimplemented("\(Self.self).fetchGamesForWord"),
      fetchStats: XCTUnimplemented("\(Self.self).fetchStats"),
      fetchVocab: XCTUnimplemented("\(Self.self).fetchVocab"),
      migrate: XCTUnimplemented("\(Self.self).migrate"),
      playedGamesCount: XCTUnimplemented("\(Self.self).playedGamesCount"),
      saveGame: XCTUnimplemented("\(Self.self).saveGame")
    )
  #endif
}
