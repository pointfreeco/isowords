import ApiClient
import Build
import ComposableArchitecture
import Dependencies
import Foundation
@_exported import ServerConfig

extension PersistenceReaderKey where Self == ServerConfigKey {
  public static var serverConfig: Self {
    ServerConfigKey()
  }
}

public struct ServerConfigKey: PersistenceReaderKey, Hashable, Sendable {
  @Dependency(\.apiClient) var apiClient
  @Shared(.build) var build = Build()
  @Shared(.fileStorage(.serverConfig)) var config = ServerConfig()
  let (stream, continuation) = AsyncStream<Void>.makeStream()

  public init() {}

  public func reload() async {
    continuation.yield()
  }

  public func load(initialValue: ServerConfig?) -> ServerConfig? {
    config
  }

  public func subscribe(
    initialValue: ServerConfig?,
    didSet: @escaping (ServerConfig?) -> Void
  ) -> Shared<ServerConfig, Self>.Subscription {
    let task = Task {
      try await didSet(
        apiClient
          .apiRequest(route: .config(build: build.number), as: ServerConfig.self)
      )
      for await _ in stream {
        let config =
          try await apiClient
          .apiRequest(route: .config(build: build.number), as: ServerConfig.self)
        didSet(config)
      }
    }
    return Shared.Subscription {
      task.cancel()
    }
  }

  public static func == (lhs: ServerConfigKey, rhs: ServerConfigKey) -> Bool {
    true
  }
  public func hash(into hasher: inout Hasher) {
  }
}

extension URL {
  fileprivate static let serverConfig = documentsDirectory.appending(path: "server-config.json")
}
