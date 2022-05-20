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
    var currentPlayer: CurrentPlayerEnvelope?

    var baseUrl = URL(string: "/")!

    self.init(
      apiRequest: { route in
        guard
          let request = try? router.request(
            for: .api(.init(accessToken: .init(rawValue: .deadbeef), isDebug: true, route: route))
          ),
          let url = request.url
        else {
          return Fail(error: URLError.init(.badURL))
            .eraseToEffect()
        }
        let conn = middleware(connection(from: request)).perform()

        let response = HTTPURLResponse(
          url: url,
          statusCode: conn.response.status.rawValue,
          httpVersion: nil,
          headerFields: Dictionary(
            uniqueKeysWithValues: conn.response.headers.map { ($0.name, $0.value) })
        )!
        return Just((conn.data, response))
          .setFailureType(to: URLError.self)
          .eraseToEffect()
      },
      authenticate: { authRequest in
        guard let request = try? router.request(for: .authenticate(authRequest))
        else {
          return Fail(error: ApiError(error: URLError(.badURL)))
            .eraseToEffect()
        }

        return Effect.catching {
          try JSONDecoder().decode(
            CurrentPlayerEnvelope.self,
            from: middleware(connection(from: request)).perform().data
          )
        }
        .mapError { ApiError(error: $0) }
        .handleEvents(
          receiveOutput: { _ in currentPlayer = .init(appleReceipt: nil, player: .blob) }
        )
        .eraseToEffect()
      },
      baseUrl: { baseUrl },
      currentPlayer: { currentPlayer },
      logout: { .fireAndForget { currentPlayer = nil } },
      refreshCurrentPlayer: { currentPlayer.map(Effect.init(value:)) ?? .none },
      request: { route in
        guard
          let request = try? router.request(for: route),
          let url = request.url
        else {
          return Fail(error: URLError.init(.badURL))
            .eraseToEffect()
        }
        let conn = middleware(connection(from: request)).perform()

        let response = HTTPURLResponse(
          url: url,
          statusCode: conn.response.status.rawValue,
          httpVersion: nil,
          headerFields: Dictionary(
            uniqueKeysWithValues: conn.response.headers.map { ($0.name, $0.value) })
        )!
        return Just((conn.data, response))
          .setFailureType(to: URLError.self)
          .eraseToEffect()
      },
      setBaseUrl: { url in
        .fireAndForget {
          baseUrl = url
        }
      }
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
