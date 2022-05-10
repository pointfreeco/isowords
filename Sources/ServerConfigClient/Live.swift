import ComposableArchitecture
import ServerConfig

extension ServerConfigClient {
  public static func live(
    fetch: @escaping () async throws -> ServerConfig
  ) -> Self {
    var currentConfig =
      (UserDefaults.standard.object(forKey: serverConfigKey) as? Data)
      .flatMap { try? jsonDecoder.decode(ServerConfig.self, from: $0) }
      ?? ServerConfig()

    return Self(
      config: { currentConfig },
      refresh: {
        currentConfig = try await fetch()
        if let data = try? jsonEncoder.encode(currentConfig) {
          UserDefaults.standard.set(data, forKey: serverConfigKey)
        }
        return currentConfig
      }
    )
  }
}

private let jsonDecoder = JSONDecoder()
private let jsonEncoder = JSONEncoder()

private let serverConfigKey = "co.pointfree.serverConfigKey"
