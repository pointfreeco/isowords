import ComposableArchitecture
import ServerConfig

public struct ServerConfigClient {
  public var config: () -> ServerConfig
  public var refresh: () -> Effect<ServerConfig, Error>
}
