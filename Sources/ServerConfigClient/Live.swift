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
    let effect = fetch()
      .handleEvents(
        receiveOutput: {
          currentConfig = $0
          guard let data = try? jsonEncoder.encode(currentConfig)
          else { return }
          UserDefaults.standard.set(data, forKey: serverConfigKey)
        }
      )
      .eraseToEffect()

    return Self(
      config: { currentConfig },
      refresh: { effect },
      refreshAsync: {
        if #available(iOS 15.0, *) {
          for try await value in effect.values {
            return value
          }
        }
        fatalError("TODO: Refactor")
      }
    )
  }
}

let jsonDecoder = JSONDecoder()
let jsonEncoder = JSONEncoder()

private let serverConfigKey = "co.pointfree.serverConfigKey"
