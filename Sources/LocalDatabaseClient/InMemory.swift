#if DEBUG
  import Foundation

  extension LocalDatabaseClient {
    public static let inMemory = Self.live(path: URL(string: ":memory:")!)
  }
#endif
