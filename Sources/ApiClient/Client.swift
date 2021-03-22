import Combine
import ComposableArchitecture
import Foundation
@_exported import ServerRoutes
import SharedModels

public struct ApiClient {
  public var apiRequest:
    (ServerRoute.Api.Route) -> Effect<(data: Data, response: URLResponse), URLError>
  public var authenticate:
    (ServerRoute.AuthenticateRequest) -> Effect<CurrentPlayerEnvelope, ApiError>
  public var baseUrl: () -> URL
  public var currentPlayer: () -> CurrentPlayerEnvelope?
  public var logout: () -> Effect<Never, Never>
  public var refreshCurrentPlayer: () -> Effect<CurrentPlayerEnvelope, ApiError>
  public var request: (ServerRoute) -> Effect<(data: Data, response: URLResponse), URLError>
  public var setBaseUrl: (URL) -> Effect<Never, Never>

  public init(
    apiRequest: @escaping (ServerRoute.Api.Route) -> Effect<
      (data: Data, response: URLResponse), URLError
    >,
    authenticate: @escaping (ServerRoute.AuthenticateRequest) -> Effect<
      CurrentPlayerEnvelope, ApiError
    >,
    baseUrl: @escaping () -> URL,
    currentPlayer: @escaping () -> CurrentPlayerEnvelope?,
    logout: @escaping () -> Effect<Never, Never>,
    refreshCurrentPlayer: @escaping () -> Effect<CurrentPlayerEnvelope, ApiError>,
    request: @escaping (ServerRoute) -> Effect<(data: Data, response: URLResponse), URLError>,
    setBaseUrl: @escaping (URL) -> Effect<Never, Never>
  ) {
    self.apiRequest = apiRequest
    self.authenticate = authenticate
    self.baseUrl = baseUrl
    self.currentPlayer = currentPlayer
    self.logout = logout
    self.refreshCurrentPlayer = refreshCurrentPlayer
    self.request = request
    self.setBaseUrl = setBaseUrl
  }

  public struct Unit: Codable {}

  public func apiRequest(
    route: ServerRoute.Api.Route,
    file: StaticString = #file,
    line: UInt = #line
  ) -> Effect<Unit, ApiError> {
    self.apiRequest(route: route, as: Unit.self, file: file, line: line)
  }

  public func apiRequest<A: Decodable>(
    route: ServerRoute.Api.Route,
    as: A.Type,
    file: StaticString = #file,
    line: UInt = #line
  ) -> Effect<A, ApiError> {
    self.apiRequest(route)
      .handleEvents(
        receiveOutput: {
          #if DEBUG
            print(
              """
                API: route: \(route), \
                status: \(($0.response as? HTTPURLResponse)?.statusCode ?? 0), \
                receive data: \(String(decoding: $0.data, as: UTF8.self))
              """
            )
          #endif
        }
      )
      .map { data, _ in data }
      .apiDecode(as: A.self, file: file, line: line)
      .print("API")
      .eraseToEffect()
  }

  public func request<A: Decodable>(
    route: ServerRoute,
    as: A.Type,
    file: StaticString = #file,
    line: UInt = #line
  ) -> Effect<A, ApiError> {
    self.request(route)
      .handleEvents(
        receiveOutput: {
          #if DEBUG
            print(
              """
                API: route: \(route), \
                status: \(($0.response as? HTTPURLResponse)?.statusCode ?? 0), \
                receive data: \(String(decoding: $0.data, as: UTF8.self))
              """
            )
          #endif
        }
      )
      .map { data, _ in data }
      .apiDecode(as: A.self, file: file, line: line)
      .print("API")
      .eraseToEffect()
  }

  public struct LeaderboardEnvelope: Codable, Equatable {
    public let entries: [Entry]

    public struct Entry: Codable, Equatable {
      public let id: UUID
      public let isYourScore: Bool
      public let playerDisplayName: String?
      public let rank: Int
      public let score: Int
    }
  }
}

#if DEBUG
  import XCTestDebugSupport
  import XCTestDynamicOverlay

  extension ApiClient {
    public static let failing = Self(
      apiRequest: { route in .failing("\(Self.self).apiRequest(\(route)) is unimplemented") },
      authenticate: { _ in .failing("\(Self.self).authenticate is unimplemented") },
      baseUrl: {
        XCTFail("\(Self.self).baseUrl is unimplemented")
        return URL(string: "/")!
      },
      currentPlayer: {
        XCTFail("\(Self.self).currentPlayer is unimplemented")
        return nil
      },
      logout: { .failing("\(Self.self).logout is unimplemented") },
      refreshCurrentPlayer: { .failing("\(Self.self).refreshCurrentPlayer is unimplemented") },
      request: { route in .failing("\(Self.self).request(\(route)) is unimplemented") },
      setBaseUrl: { _ in .failing("ApiClient.setBaseUrl is unimplemented") }
    )

    public mutating func override(
      route matchingRoute: ServerRoute.Api.Route,
      withResponse response: Effect<(data: Data, response: URLResponse), URLError>
    ) {
      let fulfill = expectation(description: "route")
      self.apiRequest = { [self] route in
        if route == matchingRoute {
          fulfill()
          return response
        } else {
          return self.apiRequest(route)
        }
      }
    }
  }
#endif

extension ApiClient {
  public static let noop = Self(
    apiRequest: { _ in .none },
    authenticate: { _ in .none },
    baseUrl: { URL(string: "/")! },
    currentPlayer: { nil },
    logout: { .none },
    refreshCurrentPlayer: { .none },
    request: { _ in .none },
    setBaseUrl: { _ in .none }
  )
}

let jsonDecoder = JSONDecoder()
