import ApiClient
import Build
import ComposableArchitecture
import Dependencies
import Foundation

@_exported import ServerConfig

@dynamicMemberLookup
public class ServerConfigClass: Equatable {
  @Dependency(\.apiClient) var apiClient
  @Shared(.build) var build = Build()
  @Shared(.fileStorage(URL.documentsDirectory.appending(path: "server-config.json")))
  var config = ServerConfig()

  public init() {}

  public func refresh() async throws {
    self.config =
      try await apiClient
      .apiRequest(route: .config(build: build.number), as: ServerConfig.self)
  }

  public subscript<Member>(dynamicMember keyPath: KeyPath<ServerConfig, Member>) -> Member {
    self.config[keyPath: keyPath]
  }

  public static func == (lhs: ServerConfigClass, rhs: ServerConfigClass) -> Bool {
    lhs === rhs
  }
}
extension PersistenceReaderKey where Self == InMemoryKey<ServerConfigClass> {
  public static var serverConfig: Self {
    inMemory("server-config")
  }
}

extension PersistenceReaderKey where Self == ServerConfigKey {
  public static var serverConfigNew: Self {
    ServerConfigKey()
  }
}

import Combine

// @Shared(.api(route)) var response = ResponseEnvelope()
// @Shared(.leaderboards(sort:type))

public struct ServerConfigKey: PersistenceReaderKey, Hashable, Sendable {
  @Dependency(\.apiClient) var apiClient
  @Shared(.build) var build = Build()
  @Shared(.fileStorage(URL.documentsDirectory.appending(path: "server-config.json")))
  var config = ServerConfig()
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
      let config = try await apiClient
        .apiRequest(route: .config(build: build.number), as: ServerConfig.self)
      didSet(config)
      for await _ in stream {
        let config = try await apiClient
          .apiRequest(route: .config(build: build.number), as: ServerConfig.self)
        didSet(config)
      }
    }
    //
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
