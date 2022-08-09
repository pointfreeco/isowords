import Combine
import ComposableArchitecture
import Foundation
import SharedModels

public struct ApiClient {
  public var apiRequest: @Sendable (ServerRoute.Api.Route) async throws -> (Data, URLResponse)
  public var authenticate:
    @Sendable (ServerRoute.AuthenticateRequest) async throws -> CurrentPlayerEnvelope
  public var baseUrl: @Sendable () -> URL
  public var currentPlayer: @Sendable () -> CurrentPlayerEnvelope?
  public var logout: @Sendable () async -> Void
  public var refreshCurrentPlayer: @Sendable () async throws -> CurrentPlayerEnvelope
  public var request: @Sendable (ServerRoute) async throws -> (Data, URLResponse)
  public var setBaseUrl: @Sendable (URL) async -> Void

  public init(
    apiRequest: @escaping @Sendable (ServerRoute.Api.Route) async throws -> (Data, URLResponse),
    authenticate: @escaping @Sendable (ServerRoute.AuthenticateRequest) async throws ->
      CurrentPlayerEnvelope,
    baseUrl: @escaping @Sendable () -> URL,
    currentPlayer: @escaping @Sendable () -> CurrentPlayerEnvelope?,
    logout: @escaping @Sendable () async -> Void,
    refreshCurrentPlayer: @escaping @Sendable () async throws -> CurrentPlayerEnvelope,
    request: @escaping @Sendable (ServerRoute) async throws -> (Data, URLResponse),
    setBaseUrl: @escaping @Sendable (URL) async -> Void
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
  ) async throws -> (Data, URLResponse) {
    do {
      let (data, response) = try await self.apiRequest(route)
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

  public func apiRequest<A: Decodable>(
    route: ServerRoute.Api.Route,
    as: A.Type,
    file: StaticString = #file,
    line: UInt = #line
  ) async throws -> A {
    let (data, _) = try await self.apiRequest(route: route, file: file, line: line)
    do {
      return try apiDecode(A.self, from: data)
    } catch {
      throw ApiError(error: error, file: file, line: line)
    }
  }

  public func request(
    route: ServerRoute,
    file: StaticString = #file,
    line: UInt = #line
  ) async throws -> (Data, URLResponse) {
    do {
      let (data, response) = try await self.request(route)
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

  public func request<A: Decodable>(
    route: ServerRoute,
    as: A.Type,
    file: StaticString = #file,
    line: UInt = #line
  ) async throws -> A {
    let (data, _) = try await self.request(route: route, file: file, line: line)
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
    public static let unimplemented = Self(
      apiRequest: XCTUnimplemented("\(Self.self).apiRequest"),
      authenticate: XCTUnimplemented("\(Self.self).authenticate"),
      baseUrl: XCTUnimplemented("\(Self.self).baseUrl", placeholder: URL(string: "/")!),
      currentPlayer: XCTUnimplemented("\(Self.self).currentPlayer"),
      logout: XCTUnimplemented("\(Self.self).logout"),
      refreshCurrentPlayer: XCTUnimplemented("\(Self.self).refreshCurrentPlayer"),
      request: XCTUnimplemented("\(Self.self).request"),
      setBaseUrl: XCTUnimplemented("\(Self.self).setBaseUrl")
    )

    public mutating func override(
      route matchingRoute: ServerRoute.Api.Route,
      withResponse response: @escaping @Sendable () async throws -> (Data, URLResponse)
    ) {
      let fulfill = expectation(description: "route")
      self.apiRequest = { @Sendable [self] route in
        if route == matchingRoute {
          fulfill()
          return try await response()
        } else {
          return try await self.apiRequest(route)
        }
      }
    }

    public mutating func override<Value>(
      routeCase matchingRoute: CasePath<ServerRoute.Api.Route, Value>,
      withResponse response: @escaping @Sendable (Value) async throws -> (Data, URLResponse)
    ) {
      let fulfill = expectation(description: "route")
      self.apiRequest = { @Sendable [self] route in
        if let value = matchingRoute.extract(from: route) {
          fulfill()
          return try await response(value)
        } else {
          return try await self.apiRequest(route)
        }
      }
    }
  }
#endif

extension ApiClient {
  public static let noop = Self(
    apiRequest: { _ in try await Task.never() },
    authenticate: { _ in try await Task.never() },
    baseUrl: { URL(string: "/")! },
    currentPlayer: { nil },
    logout: {},
    refreshCurrentPlayer: { try await Task.never() },
    request: { _ in try await Task.never() },
    setBaseUrl: { _ in }
  )
}

let jsonDecoder = JSONDecoder()
