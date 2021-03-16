import ComposableArchitecture
import ServerConfig

extension ServerConfigClient {
  public static func live(
    fetch: @escaping () -> Effect<ServerConfig, Error>
  ) -> Self {
    var currentConfig =
      (UserDefaults.standard.object(forKey: serverConfigKey) as? Data)
      .flatMap { try? jsonDecoder.decode(ServerConfig.self, from: $0) }
      ?? ServerConfig()

    return Self(
      config: { currentConfig },
      refresh: {
        fetch()
          .handleEvents(
            receiveOutput: {
              currentConfig = $0
              guard let data = try? jsonEncoder.encode(currentConfig)
              else { return }
              UserDefaults.standard.set(data, forKey: serverConfigKey)
            }
          )
          .eraseToEffect()
      }
    )
  }
}

let jsonDecoder = JSONDecoder()
let jsonEncoder = JSONEncoder()

private let serverConfigKey = "co.pointfree.serverConfigKey"
