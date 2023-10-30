import DependenciesMacros
@_exported import ServerConfig

@DependencyClient
public struct ServerConfigClient {
  public var config: () -> ServerConfig = { .init() }
  public var refresh: @Sendable () async throws -> ServerConfig
}
