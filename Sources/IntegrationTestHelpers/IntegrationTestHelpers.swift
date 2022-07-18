import ApiClient
import Combine
import ComposableArchitecture
import FirstPartyMocks
import Foundation
import HttpPipeline
import Prelude
import ServerRouter
import SharedModels
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
      var baseUrl: URL
      var currentPlayer: CurrentPlayerEnvelope?
      private let middleware: Middleware<StatusLineOpen, ResponseEnded, Prelude.Unit, Data>
      private let router: ServerRouter

      init(
        baseUrl: URL,
        middleware: @escaping Middleware<StatusLineOpen, ResponseEnded, Prelude.Unit, Data>,
        router: ServerRouter
      ) {
        self.baseUrl = baseUrl
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
          currentPlayer = .init(appleReceipt: nil, player: .blob)
          return envelope
        } catch {
          throw ApiError(error: error)
        }
      }

      func logout() {
        self.currentPlayer = nil
      }

      func refreshCurrentPlayer() async throws -> CurrentPlayerEnvelope {
        guard let currentPlayer = self.currentPlayer
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
        self.baseUrl = url
      }

      fileprivate func setCurrentPlayer(_ player: CurrentPlayerEnvelope) {
        self.currentPlayer = player
      }
    }

    let session = Session(baseUrl: baseUrl, middleware: middleware, router: router)

    self.init(
      apiRequest: { try await session.apiRequest(route: $0) },
      authenticate: { try await session.authenticate(request: $0) },
      baseUrl: { baseUrl },
      baseUrlAsync: { await session.baseUrl },
      currentPlayer: { currentPlayer },
      currentPlayerAsync: { await session.currentPlayer },
      logout: { await session.logout() },
      refreshCurrentPlayerAsync: { try await session.refreshCurrentPlayer() },
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
