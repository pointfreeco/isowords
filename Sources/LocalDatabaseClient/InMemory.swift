#if DEBUG
  import ComposableArchitecture
  import Foundation
  import SQLite3

  extension LocalDatabaseClient {
    public static let inMemory = Self.live(path: URL(string: ":memory:")!)
  }
#endif
