import ComposableArchitecture
import ServerConfig

extension ServerConfigClient {
  public static func live(
    fetch: @escaping @Sendable () async throws -> ServerConfig
  ) -> Self {
    var currentConfig =
      (UserDefaults.standard.object(forKey: serverConfigKey) as? Data)
      .flatMap { try? jsonDecoder.decode(ServerConfig.self, from: $0) }
    ?? ServerConfig() {
      didSet {
        guard let data = try? jsonEncoder.encode(currentConfig)
        else { return }
        UserDefaults.standard.set(data, forKey: serverConfigKey)
      }
    }

    return Self(
      config: { currentConfig },
      refresh: {
        let config = try await fetch()
        currentConfig = config
        return config
      }
    )
  }
}

let jsonDecoder = JSONDecoder()
let jsonEncoder = JSONEncoder()

private let serverConfigKey = "co.pointfree.serverConfigKey"
