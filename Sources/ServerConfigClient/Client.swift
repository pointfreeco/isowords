import DependenciesMacros
@_exported import ServerConfig

@DependencyClient
public struct ServerConfigClient {
  public var config: () -> ServerConfig = { ServerConfig() }
  public var refresh: @Sendable () async throws -> ServerConfig
}
