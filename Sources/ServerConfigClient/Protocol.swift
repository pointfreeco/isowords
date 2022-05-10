import Foundation

public protocol _ServerConfigClient {
  var config: ServerConfig { get async }
  func refresh() async throws -> ServerConfig
}

actor LiveServerConfig: _ServerConfigClient {
  private(set) var config: ServerConfig
  private let fetch: () async throws -> ServerConfig

  public init(fetch: @escaping () async throws -> ServerConfig) {
    self.config = (UserDefaults.standard.object(forKey: serverConfigKey) as? Data)
      .flatMap { try? jsonDecoder.decode(ServerConfig.self, from: $0) }
    ?? .init()
    self.fetch = fetch
  }

  func refresh() async throws -> ServerConfig {
    self.config = try await fetch()
    if let data = try? jsonEncoder.encode(self.config) {
      UserDefaults.standard.set(data, forKey: serverConfigKey)
    }
    return self.config
  }
}

private let jsonDecoder = JSONDecoder()
private let jsonEncoder = JSONEncoder()

private let serverConfigKey = "co.pointfree.serverConfigKey"
