import ComposableArchitecture
@_exported import ServerConfig

extension DependencyValues {
  public var serverConfig: ServerConfigClient {
    get { self[ServerConfigClientKey.self] }
    set { self[ServerConfigClientKey.self] = newValue }
  }

  private enum ServerConfigClientKey: TestDependencyKey {
    static let testValue = ServerConfigClient.unimplemented
  }
}

public struct ServerConfigClient {
  public var config: () -> ServerConfig
  public var refresh: @Sendable () async throws -> ServerConfig
}
