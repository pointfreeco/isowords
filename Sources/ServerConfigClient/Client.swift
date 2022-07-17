import ComposableArchitecture
@_exported import ServerConfig

public struct ServerConfigClient {
  public var config: () -> ServerConfig
  public var refresh: @Sendable () async throws -> ServerConfig
}
