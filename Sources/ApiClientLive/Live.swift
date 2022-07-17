@_exported import ApiClient
import Combine
import ComposableArchitecture
import Foundation
import ServerRouter
import SharedModels

private let baseUrlKey = "co.pointfree.isowords.apiClient.baseUrl"
private let currentUserEnvelopeKey = "co.pointfree.isowords.apiClient.currentUserEnvelope"

extension ApiClient {
  public static func live(
    baseUrl defaultBaseUrl: URL = URL(string: "http://localhost:9876")!,
    sha256: @escaping (Data) -> Data
  ) -> Self {

    #if DEBUG
      var baseUrl = UserDefaults.standard.url(forKey: baseUrlKey) ?? defaultBaseUrl {
        didSet {
          UserDefaults.standard.set(baseUrl, forKey: baseUrlKey)
        }
      }
    #else
      var baseUrl = URL(string: "https://www.isowords.xyz")!
    #endif

    let router = ServerRouter(
      date: Date.init,
      decoder: decoder,
      encoder: encoder,
      secrets: secrets.split(separator: ",").map(String.init),
      sha256: sha256
    )

    var currentPlayer = UserDefaults.standard.data(forKey: currentUserEnvelopeKey)
      .flatMap({ try? decoder.decode(CurrentPlayerEnvelope.self, from: $0) })
    {
      didSet {
        UserDefaults.standard.set(
          currentPlayer.flatMap { try? encoder.encode($0) },
          forKey: currentUserEnvelopeKey
        )
      }
    }

    actor Session {
      var baseUrl: URL {
        didSet {
          UserDefaults.standard.set(self.baseUrl, forKey: baseUrlKey)
        }
      }
      var currentPlayer: CurrentPlayerEnvelope? {
        didSet {
          UserDefaults.standard.set(
            self.currentPlayer.flatMap { try? encoder.encode($0) },
            forKey: currentUserEnvelopeKey
          )
        }
      }
      private let router: ServerRouter

      init(baseUrl: URL, router: ServerRouter) {
        self.baseUrl = baseUrl
        self.router = router
      }

      func apiRequest(route: ServerRoute.Api.Route) async throws -> (Data, URLResponse) {
        try await ApiClientLive.apiRequest(
          accessToken: self.currentPlayer?.player.accessToken,
          baseUrl: self.baseUrl,
          route: route,
          router: self.router
        )
      }

      func authenticate(request: ServerRoute.AuthenticateRequest) async throws
        -> CurrentPlayerEnvelope
      {
        let (data, _) = try await ApiClientLive.request(
          baseUrl: baseUrl,
          route: .authenticate(
            .init(
              deviceId: request.deviceId,
              displayName: request.displayName,
              gameCenterLocalPlayerId: request.gameCenterLocalPlayerId,
              timeZone: request.timeZone
            )
          ),
          router: router
        )
        let currentPlayer = try apiDecode(CurrentPlayerEnvelope.self, from: data)
        self.currentPlayer = currentPlayer
        return currentPlayer
      }

      func logout() {
        self.currentPlayer = nil
      }

      func refreshCurrentPlayer() async throws -> CurrentPlayerEnvelope {
        let (data, _) = try await ApiClientLive.apiRequest(
          accessToken: currentPlayer?.player.accessToken,
          baseUrl: self.baseUrl,
          route: .currentPlayer,
          router: self.router
        )
        let currentPlayer = try apiDecode(CurrentPlayerEnvelope.self, from: data)
        self.currentPlayer = currentPlayer
        return currentPlayer
      }

      func request(route: ServerRoute) async throws -> (Data, URLResponse) {
        try await ApiClientLive.request(
          baseUrl: self.baseUrl,
          route: route,
          router: self.router
        )
      }

      func setBaseUrl(_ url: URL) {
        self.baseUrl = url
      }

      fileprivate func setCurrentPlayer(_ player: CurrentPlayerEnvelope) {
        self.currentPlayer = player
      }
    }

    let session = Session(baseUrl: baseUrl, router: router)

    return Self(
      apiRequest: { try await session.apiRequest(route: $0) },
      authenticate: { try await session.authenticate(request: $0) },
      baseUrl: { baseUrl },
      baseUrlAsync: { await session.baseUrl },
      currentPlayer: { currentPlayer },
      currentPlayerAsync: { await session.currentPlayer },
      logout: {
        .fireAndForget {
          currentPlayer = nil
          Task { await session.logout() }
        }
      },
      logoutAsync: { await session.logout() },
      refreshCurrentPlayer: {
        ApiClientLive.apiRequest(
          accessToken: currentPlayer?.player.accessToken,
          baseUrl: baseUrl,
          route: .currentPlayer,
          router: router
        )
        .map { data, _ in data }
        .apiDecode(as: CurrentPlayerEnvelope.self)
        .handleEvents(
          receiveOutput: { newPlayer in
            DispatchQueue.main.async {
              currentPlayer = newPlayer
              Task { await session.setCurrentPlayer(newPlayer) }
            }
          }
        )
        .eraseToEffect()
      },
      refreshCurrentPlayerAsync: {
        let newPlayer = try await session.refreshCurrentPlayer()
//        currentPlayer = newPlayer  // TODO: remove
        return newPlayer
      },
      request: { try await session.request(route: $0) },
      setBaseUrl: { url in
        .fireAndForget {
          baseUrl = url
          Task { await session.setBaseUrl(url) }
        }
      },
      setBaseUrlAsync: {
        await session.setBaseUrl($0)
//        baseUrl = $0  // TODO: remove
      }
    )
  }
}

private func request(
  baseUrl: URL,
  route: ServerRoute,
  router: ServerRouter
) -> Effect<(data: Data, response: URLResponse), URLError> {
  Deferred { () -> Effect<(data: Data, response: URLResponse), URLError> in
    guard var request = try? router.baseURL(baseUrl.absoluteString).request(for: route)
    else { return .init(error: URLError(.badURL)) }
    request.setHeaders()
    return URLSession.shared.dataTaskPublisher(for: request)
      .eraseToEffect()
  }
  .eraseToEffect()
}

private func request(
  baseUrl: URL,
  route: ServerRoute,
  router: ServerRouter
) async throws -> (Data, URLResponse) {
  guard var request = try? router.baseURL(baseUrl.absoluteString).request(for: route)
  else { throw URLError(.badURL) }
  request.setHeaders()
  if #available(iOS 15.0, *) {
    return try await URLSession.shared.data(for: request)
  } else {
    fatalError()
  }
}

private func apiRequest(
  accessToken: AccessToken?,
  baseUrl: URL,
  route: ServerRoute.Api.Route,
  router: ServerRouter
) -> Effect<(data: Data, response: URLResponse), URLError> {

  return Deferred { () -> Effect<(data: Data, response: URLResponse), URLError> in
    guard let accessToken = accessToken
    else { return .init(error: URLError(.userAuthenticationRequired)) }

    return request(
      baseUrl: baseUrl,
      route: .api(
        .init(
          accessToken: accessToken,
          isDebug: isDebug,
          route: route
        )
      ),
      router: router
    )
  }
  .eraseToEffect()
}

private func apiRequest(
  accessToken: AccessToken?,
  baseUrl: URL,
  route: ServerRoute.Api.Route,
  router: ServerRouter
) async throws -> (Data, URLResponse) {

  guard let accessToken = accessToken
  else { throw URLError(.userAuthenticationRequired) }

  return try await request(
    baseUrl: baseUrl,
    route: .api(
      .init(
        accessToken: accessToken,
        isDebug: isDebug,
        route: route
      )
    ),
    router: router
  )
}

#if DEBUG
  private let isDebug = true
#else
  private let isDebug = false
#endif

extension URLRequest {
  fileprivate mutating func setHeaders() {
    guard let infoDictionary = Bundle.main.infoDictionary else { return }

    let bundleName = infoDictionary[kCFBundleNameKey as String] ?? "isowords"
    let marketingVersion = infoDictionary["CFBundleShortVersionString"].map { "/\($0)" } ?? ""
    let bundleVersion = infoDictionary[kCFBundleVersionKey as String].map { " bundle/\($0)" } ?? ""
    let gitSha = (infoDictionary["GitSHA"] as? String).map { $0.isEmpty ? "" : "git/\($0)" } ?? ""

    self.setValue(
      "\(bundleName)\(marketingVersion)\(bundleVersion)\(gitSha)", forHTTPHeaderField: "User-Agent")
  }
}

private let encoder = { () -> JSONEncoder in
  let encoder = JSONEncoder()
  encoder.dateEncodingStrategy = .secondsSince1970
  return encoder
}()

private let decoder = { () -> JSONDecoder in
  let decoder = JSONDecoder()
  decoder.dateDecodingStrategy = .secondsSince1970
  return decoder
}()
