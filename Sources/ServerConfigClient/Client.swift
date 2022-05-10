import ComposableArchitecture
@_exported import ServerConfig

public struct ServerConfigClient {
  public var config: () -> ServerConfig
  public var refresh: () async throws -> ServerConfig
}
