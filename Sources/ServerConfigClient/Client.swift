import ComposableArchitecture
@_exported import ServerConfig

public struct ServerConfigClient {
  public var config: () -> ServerConfig
  public var refresh: () -> Effect<ServerConfig, Error>
  public var refreshAsync: @Sendable () async throws -> ServerConfig
}
