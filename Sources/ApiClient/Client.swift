import Combine
import ComposableArchitecture
import Foundation
import SharedModels

public struct ApiClient {
  @available(*, deprecated) public var apiRequest:
    (ServerRoute.Api.Route) -> Effect<(data: Data, response: URLResponse), URLError>
  public var apiRequestAsync: @Sendable (ServerRoute.Api.Route) async throws -> (Data, URLResponse)
  @available(*, deprecated) public var authenticate:
    (ServerRoute.AuthenticateRequest) -> Effect<CurrentPlayerEnvelope, ApiError>
  public var authenticateAsync:
    @Sendable (ServerRoute.AuthenticateRequest) async throws -> CurrentPlayerEnvelope
  @available(*, deprecated) public var baseUrl: () -> URL
  public var baseUrlAsync: @Sendable () async -> URL
  @available(*, deprecated) public var currentPlayer: () -> CurrentPlayerEnvelope?
  public var currentPlayerAsync: @Sendable () async -> CurrentPlayerEnvelope?
  @available(*, deprecated) public var logout: () -> Effect<Never, Never>
  public var logoutAsync: @Sendable () async -> Void
  @available(*, deprecated) public var refreshCurrentPlayer: () -> Effect<CurrentPlayerEnvelope, ApiError>
  public var refreshCurrentPlayerAsync: @Sendable () async throws -> CurrentPlayerEnvelope
  @available(*, deprecated) public var request: (ServerRoute) -> Effect<(data: Data, response: URLResponse), URLError>
  public var requestAsync: @Sendable (ServerRoute) async throws -> (Data, URLResponse)
  @available(*, deprecated) public var setBaseUrl: (URL) -> Effect<Never, Never>
  public var setBaseUrlAsync: @Sendable (URL) async -> Void

  public init(
    apiRequest: @escaping (ServerRoute.Api.Route) -> Effect<
      (data: Data, response: URLResponse), URLError
    >,
    apiRequestAsync: @escaping @Sendable (ServerRoute.Api.Route) async throws -> (
      Data, URLResponse
    ),
    authenticate: @escaping (ServerRoute.AuthenticateRequest) -> Effect<
      CurrentPlayerEnvelope, ApiError
    >,
    authenticateAsync: @escaping @Sendable (ServerRoute.AuthenticateRequest) async throws ->
      CurrentPlayerEnvelope,
    baseUrl: @escaping () -> URL,
    baseUrlAsync: @escaping @Sendable () async -> URL,
    currentPlayer: @escaping () -> CurrentPlayerEnvelope?,
    currentPlayerAsync: @escaping @Sendable () async -> CurrentPlayerEnvelope?,
    logout: @escaping () -> Effect<Never, Never>,
    logoutAsync: @escaping @Sendable () async -> Void,
    refreshCurrentPlayer: @escaping () -> Effect<CurrentPlayerEnvelope, ApiError>,
    refreshCurrentPlayerAsync: @escaping @Sendable () async throws -> CurrentPlayerEnvelope,
    request: @escaping (ServerRoute) -> Effect<(data: Data, response: URLResponse), URLError>,
    requestAsync: @escaping @Sendable (ServerRoute) async throws -> (Data, URLResponse),
    setBaseUrl: @escaping (URL) -> Effect<Never, Never>,
    setBaseUrlAsync: @escaping @Sendable (URL) async -> Void
  ) {
    self.apiRequest = apiRequest
    self.apiRequestAsync = apiRequestAsync
    self.authenticate = authenticate
    self.authenticateAsync = authenticateAsync
    self.baseUrl = baseUrl
    self.baseUrlAsync = baseUrlAsync
    self.currentPlayer = currentPlayer
    self.currentPlayerAsync = currentPlayerAsync
    self.logout = logout
    self.logoutAsync = logoutAsync
    self.refreshCurrentPlayer = refreshCurrentPlayer
    self.refreshCurrentPlayerAsync = refreshCurrentPlayerAsync
    self.request = request
    self.requestAsync = requestAsync
    self.setBaseUrl = setBaseUrl
    self.setBaseUrlAsync = setBaseUrlAsync
  }

  public struct Unit: Codable {}

  @available(*, deprecated) public func apiRequest(
    route: ServerRoute.Api.Route,
    file: StaticString = #file,
    line: UInt = #line
  ) -> Effect<Unit, ApiError> {
    self.apiRequest(route: route, as: Unit.self, file: file, line: line)
  }

  @available(*, deprecated) public func apiRequest<A: Decodable>(
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

  public func apiRequestAsync(
    route: ServerRoute.Api.Route,
    file: StaticString = #file,
    line: UInt = #line
  ) async throws -> (Data, URLResponse) {
    do {
      let (data, response) = try await self.apiRequestAsync(route)
      #if DEBUG
        print(
          """
          API: route: \(route), \
          status: \((response as? HTTPURLResponse)?.statusCode ?? 0), \
          receive data: \(String(decoding: data, as: UTF8.self))
          """
        )
      #endif
      return (data, response)
    } catch {
      throw ApiError(error: error, file: file, line: line)
    }
  }

  public func apiRequestAsync<A: Decodable>(
    route: ServerRoute.Api.Route,
    as: A.Type,
    file: StaticString = #file,
    line: UInt = #line
  ) async throws -> A {
    let (data, _) = try await self.apiRequestAsync(route: route, file: file, line: line)
    do {
      return try apiDecode(A.self, from: data)
    } catch {
      throw ApiError(error: error, file: file, line: line)
    }
  }

  @available(*, deprecated) public func request<A: Decodable>(
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

  public func requestAsync(
    route: ServerRoute,
    file: StaticString = #file,
    line: UInt = #line
  ) async throws -> (Data, URLResponse) {
    do {
      let (data, response) = try await self.requestAsync(route)
      #if DEBUG
        print(
          """
          API: route: \(route), \
          status: \((response as? HTTPURLResponse)?.statusCode ?? 0), \
          receive data: \(String(decoding: data, as: UTF8.self))
          """
        )
      #endif
      return (data, response)
    } catch {
      throw ApiError(error: error, file: file, line: line)
    }
  }

  public func requestAsync<A: Decodable>(
    route: ServerRoute,
    as: A.Type,
    file: StaticString = #file,
    line: UInt = #line
  ) async throws -> A {
    let (data, _) = try await self.requestAsync(route: route, file: file, line: line)
    do {
      return try apiDecode(A.self, from: data)
    } catch {
      throw ApiError(error: error, file: file, line: line)
    }
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
      apiRequestAsync: XCTUnimplemented("\(Self.self).apiRequestAsync"),
      authenticate: { _ in .failing("\(Self.self).authenticate is unimplemented") },
      authenticateAsync: XCTUnimplemented("\(Self.self).authenticateAsync"),
      baseUrl: XCTUnimplemented("\(Self.self).baseUrl", placeholder: URL(string: "/")!),
      baseUrlAsync: XCTUnimplemented("\(Self.self).baseUrlAsync", placeholder: URL(string: "/")!),
      currentPlayer: XCTUnimplemented("\(Self.self).currentPlayer"),
      currentPlayerAsync: XCTUnimplemented("\(Self.self).currentPlayerAsync"),
      logout: { .failing("\(Self.self).logout is unimplemented") },
      logoutAsync: XCTUnimplemented("\(Self.self).logoutAsync"),
      refreshCurrentPlayer: { .failing("\(Self.self).refreshCurrentPlayer is unimplemented") },
      refreshCurrentPlayerAsync: XCTUnimplemented("\(Self.self).refreshCurrentPlayerAsync"),
      request: { route in .failing("\(Self.self).request(\(route)) is unimplemented") },
      requestAsync: XCTUnimplemented("\(Self.self).requestAsync"),
      setBaseUrl: { _ in .failing("ApiClient.setBaseUrl is unimplemented") },
      setBaseUrlAsync: XCTUnimplemented("ApiClient.setBaseUrlAsync")
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
      self.apiRequestAsync = { [self] route in
        if route == matchingRoute {
          fulfill()
          return try await response.values.first(where: { _ in true })!
        } else {
          return try await self.apiRequestAsync(route)
        }
      }
    }

    public mutating func override<Value>(
      routeCase matchingRoute: CasePath<ServerRoute.Api.Route, Value>,
      withResponse response: @escaping (Value) -> Effect<
        (data: Data, response: URLResponse), URLError
      >
    ) {
      let fulfill = expectation(description: "route")
      self.apiRequest = { [self] route in
        if let value = matchingRoute.extract(from: route) {
          fulfill()
          return response(value)
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
    apiRequestAsync: { _ in try await Task.never() },
    authenticate: { _ in .none },
    authenticateAsync: { _ in try await Task.never() },
    baseUrl: { URL(string: "/")! },
    baseUrlAsync: { URL(string: "/")! },
    currentPlayer: { nil },
    currentPlayerAsync: { nil },
    logout: { .none },
    logoutAsync: {},
    refreshCurrentPlayer: { .none },
    refreshCurrentPlayerAsync: { try await Task.never() },
    request: { _ in .none },
    requestAsync: { _ in try await Task.never() },
    setBaseUrl: { _ in .none },
    setBaseUrlAsync: { _ in }
  )
}

let jsonDecoder = JSONDecoder()
