@_exported import ApiClient
import Combine
import CryptoKit
import Dependencies
import Foundation
import ServerRouter
import SharedModels
import TcaHelpers

extension ApiClient: DependencyKey {
  public static let liveValue = Self.live(
    sha256: { Data(SHA256.hash(data: $0)) }
  )

  public static func live(
    baseUrl defaultBaseUrl: URL = URL(string: "http://localhost:9876")!,
    sha256: @escaping (Data) -> Data
  ) -> Self {

    #if DEBUG
      let baseUrl = UserDefaults.standard.url(forKey: baseUrlKey) ?? defaultBaseUrl
    #else
      let baseUrl = URL(string: "https://www.isowords.xyz")!
    #endif

    let router = ServerRouter(
      date: Date.init,
      decoder: decoder,
      encoder: encoder,
      secrets: secrets.split(separator: ",").map(String.init),
      sha256: sha256
    )

    actor Session {
      nonisolated let baseUrl: Isolated<URL>
      nonisolated let currentPlayer: Isolated<CurrentPlayerEnvelope?>
      private let router: ServerRouter

      init(baseUrl: URL, router: ServerRouter) {
        self.baseUrl = Isolated(
          baseUrl,
          didSet: { _, newValue in
            UserDefaults.standard.set(newValue, forKey: baseUrlKey)
          }
        )
        self.router = router
        self.currentPlayer = Isolated(
          UserDefaults.standard.data(forKey: currentUserEnvelopeKey)
            .flatMap({ try? decoder.decode(CurrentPlayerEnvelope.self, from: $0) }),
          didSet: { _, newValue in
            UserDefaults.standard.set(
              newValue.flatMap { try? encoder.encode($0) },
              forKey: currentUserEnvelopeKey
            )
          }
        )
      }

      func apiRequest(route: ServerRoute.Api.Route) async throws -> (Data, URLResponse) {
        try await ApiClientLive.apiRequest(
          accessToken: self.currentPlayer.value?.player.accessToken,
          baseUrl: self.baseUrl.value,
          route: route,
          router: self.router
        )
      }

      func authenticate(request: ServerRoute.AuthenticateRequest) async throws
        -> CurrentPlayerEnvelope
      {
        let (data, _) = try await ApiClientLive.request(
          baseUrl: self.baseUrl.value,
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
        self.currentPlayer.value = currentPlayer
        return currentPlayer
      }

      func logout() {
        self.currentPlayer.value = nil
      }

      func refreshCurrentPlayer() async throws -> CurrentPlayerEnvelope {
        let (data, _) = try await ApiClientLive.apiRequest(
          accessToken: self.currentPlayer.value?.player.accessToken,
          baseUrl: self.baseUrl.value,
          route: .currentPlayer,
          router: self.router
        )
        let currentPlayer = try apiDecode(CurrentPlayerEnvelope.self, from: data)
        self.currentPlayer.value = currentPlayer
        return currentPlayer
      }

      func request(route: ServerRoute) async throws -> (Data, URLResponse) {
        try await ApiClientLive.request(
          baseUrl: self.baseUrl.value,
          route: route,
          router: self.router
        )
      }

      func setBaseUrl(_ url: URL) {
        self.baseUrl.value = url
      }

      fileprivate func setCurrentPlayer(_ player: CurrentPlayerEnvelope) {
        self.currentPlayer.value = player
      }
    }

    let session = Session(baseUrl: baseUrl, router: router)

    return Self(
      apiRequest: { try await session.apiRequest(route: $0) },
      authenticate: { try await session.authenticate(request: $0) },
      baseUrl: { session.baseUrl.value },
      currentPlayer: { session.currentPlayer.value },
      logout: { await session.logout() },
      refreshCurrentPlayer: { try await session.refreshCurrentPlayer() },
      request: { try await session.request(route: $0) },
      setBaseUrl: { await session.setBaseUrl($0) }
    )
  }
}

private let baseUrlKey = "co.pointfree.isowords.apiClient.baseUrl"
private let currentUserEnvelopeKey = "co.pointfree.isowords.apiClient.currentUserEnvelope"

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
