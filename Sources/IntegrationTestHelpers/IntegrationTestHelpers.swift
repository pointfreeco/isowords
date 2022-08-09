import ApiClient
import Combine
import ComposableArchitecture
import FirstPartyMocks
import Foundation
import HttpPipeline
import Prelude
import ServerRouter
import SharedModels
import TcaHelpers
import TestHelpers

extension ApiClient {
  public init(
    middleware: @escaping Middleware<StatusLineOpen, ResponseEnded, Prelude.Unit, Data>,
    router: ServerRouter
  ) {
    // TODO: Fix sync interfaces or migrate fully to async
    var currentPlayer: CurrentPlayerEnvelope?
    var baseUrl = URL(string: "/")!

    actor Session {
      nonisolated let baseUrl: Isolated<URL>
      nonisolated let currentPlayer = Isolated<CurrentPlayerEnvelope?>(nil)
      private let middleware: Middleware<StatusLineOpen, ResponseEnded, Prelude.Unit, Data>
      private let router: ServerRouter

      init(
        baseUrl: URL,
        middleware: @escaping Middleware<StatusLineOpen, ResponseEnded, Prelude.Unit, Data>,
        router: ServerRouter
      ) {
        self.baseUrl = Isolated(baseUrl)
        self.middleware = middleware
        self.router = router
      }

      func apiRequest(route: ServerRoute.Api.Route) async throws -> (Data, URLResponse) {
        guard
          let request = try? router.request(
            for: .api(.init(accessToken: .init(rawValue: .deadbeef), isDebug: true, route: route))
          ),
          let url = request.url
        else { throw URLError.init(.badURL) }

        let conn = middleware(connection(from: request)).perform()

        let response = HTTPURLResponse(
          url: url,
          statusCode: conn.response.status.rawValue,
          httpVersion: nil,
          headerFields: Dictionary(
            uniqueKeysWithValues: conn.response.headers.map { ($0.name, $0.value) })
        )!
        return (conn.data, response)
      }

      func authenticate(request: ServerRoute.AuthenticateRequest) async throws
        -> CurrentPlayerEnvelope
      {
        do {
          guard let request = try? self.router.request(for: .authenticate(request))
          else { throw URLError(.badURL) }

          let envelope = try JSONDecoder().decode(
            CurrentPlayerEnvelope.self,
            from: middleware(connection(from: request)).perform().data
          )
          // Why aren't we assigning the envelope here?
          self.currentPlayer.value = .init(appleReceipt: nil, player: .blob)
          return envelope
        } catch {
          throw ApiError(error: error)
        }
      }

      func logout() {
        self.currentPlayer.value = nil
      }

      func refreshCurrentPlayer() async throws -> CurrentPlayerEnvelope {
        guard let currentPlayer = self.currentPlayer.value
        else { throw URLError(.unknown) }
        return currentPlayer
      }

      func request(route: ServerRoute) async throws -> (Data, URLResponse) {
        guard
          let request = try? self.router.request(for: route),
          let url = request.url
        else { throw URLError.init(.badURL) }

        let conn = middleware(connection(from: request)).perform()

        let response = HTTPURLResponse(
          url: url,
          statusCode: conn.response.status.rawValue,
          httpVersion: nil,
          headerFields: Dictionary(
            uniqueKeysWithValues: conn.response.headers.map { ($0.name, $0.value) })
        )!
        return (conn.data, response)
      }

      func setBaseUrl(_ url: URL) {
        self.baseUrl.value = url
      }

      fileprivate func setCurrentPlayer(_ player: CurrentPlayerEnvelope) {
        self.currentPlayer.value = player
      }
    }

    let session = Session(baseUrl: baseUrl, middleware: middleware, router: router)

    self.init(
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

private let encoder = { () -> JSONEncoder in
  let encoder = JSONEncoder()
  encoder.outputFormatting = .sortedKeys
  encoder.dateEncodingStrategy = .secondsSince1970
  return encoder
}()

private let decoder = { () -> JSONDecoder in
  let decoder = JSONDecoder()
  decoder.dateDecodingStrategy = .secondsSince1970
  return decoder
}()
