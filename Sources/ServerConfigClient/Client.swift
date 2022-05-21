import ComposableArchitecture
@_exported import ServerConfig

public struct ServerConfigClient {
  public var config: () -> ServerConfig
  public var refresh: () -> Effect<ServerConfig, Error>
}

extension DependencyValues {
  public var serverConfig: ServerConfigClient {
    get { self[ServerConfigClientKey.self] }
    set { self[ServerConfigClientKey.self] = newValue }
  }

  private enum ServerConfigClientKey: DependencyKey {
    static let testValue = ServerConfigClient.failing
  }
}
