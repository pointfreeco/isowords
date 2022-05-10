import CasePaths
import Foundation
import SharedModels

public struct ApiClient {
  public var apiRequest:
    (ServerRoute.Api.Route) async throws -> (data: Data, response: URLResponse)
  public var authenticate:
    (ServerRoute.AuthenticateRequest) async throws -> CurrentPlayerEnvelope
  public var baseUrl: () -> URL
  public var currentPlayer: () -> CurrentPlayerEnvelope?
  public var logout: () async -> Void
  public var refreshCurrentPlayer: () async throws -> CurrentPlayerEnvelope
  public var request: (ServerRoute) async throws -> (data: Data, response: URLResponse)
  public var setBaseUrl: (URL) async -> Void

  public init(
    apiRequest: @escaping (ServerRoute.Api.Route) async throws -> (data: Data, response: URLResponse),
    authenticate: @escaping (ServerRoute.AuthenticateRequest) async throws -> CurrentPlayerEnvelope,
    baseUrl: @escaping () -> URL,
    currentPlayer: @escaping () -> CurrentPlayerEnvelope?,
    logout: @escaping () async -> Void,
    refreshCurrentPlayer: @escaping () async throws -> CurrentPlayerEnvelope,
    request: @escaping (ServerRoute) async throws -> (data: Data, response: URLResponse),
    setBaseUrl: @escaping (URL) async -> Void
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
  ) async throws {
    _ = try await self.apiRequest(route: route, as: Unit.self, file: file, line: line)
  }

  public func apiRequest<A: Decodable>(
    route: ServerRoute.Api.Route,
    as: A.Type,
    file: StaticString = #file,
    line: UInt = #line
  ) async throws -> A {
    let (data, response): (Data, URLResponse)
    do {
      (data, response) = try await self.apiRequest(route)
    } catch {
      throw ApiError(error: error)
    }
#if DEBUG
    print(
      """
        API: route: \(route), \
        status: \((response as? HTTPURLResponse)?.statusCode ?? 0), \
        receive data: \(String(decoding: data, as: UTF8.self))
      """
    )
#endif
    let value: A
    do {
      value = try jsonDecoder.decode(A.self, from: data)
    } catch let decodingError {
      do {
        throw try jsonDecoder.decode(ApiError.self, from: data)
      } catch {
        throw ApiError(error: decodingError)
      }
    }

    return value
  }

  public func request<A: Decodable>(
    route: ServerRoute,
    as: A.Type,
    file: StaticString = #file,
    line: UInt = #line
  ) async throws -> A {
    let (data, response): (Data, URLResponse)
    do {
      (data, response) = try await self.request(route)
    } catch {
      throw ApiError(error: error)
    }
#if DEBUG
    print(
      """
        API: route: \(route), \
        status: \((response as? HTTPURLResponse)?.statusCode ?? 0), \
        receive data: \(String(decoding: data, as: UTF8.self))
      """
    )
#endif
    let value: A
    do {
      value = try jsonDecoder.decode(A.self, from: data)
    } catch let decodingError {
      do {
        throw try jsonDecoder.decode(ApiError.self, from: data)
      } catch {
        throw ApiError(error: decodingError)
      }
    }
    
    return value
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
    struct Unimplemented: Error {}
    public static let failing = Self(
      apiRequest: { route in
        XCTFail("\(Self.self).apiRequest(\(route)) is unimplemented")
        throw Unimplemented()
      },
      authenticate: { _ in
        XCTFail("\(Self.self).authenticate is unimplemented")
        throw Unimplemented()
      },
      baseUrl: {
        XCTFail("\(Self.self).baseUrl is unimplemented")
        return .init(string: "/")!
      },
      currentPlayer: {
        XCTFail("\(Self.self).currentPlayer is unimplemented")
        return nil
      },
      logout: {
        XCTFail("\(Self.self).logout is unimplemented")
      },
      refreshCurrentPlayer: {
        XCTFail("\(Self.self).refreshCurrentPlayer is unimplemented")
        throw Unimplemented()
      },
      request: { route in
        XCTFail("\(Self.self).request(\(route)) is unimplemented")
        throw Unimplemented()
      },
      setBaseUrl: { _ in
        XCTFail("ApiClient.setBaseUrl is unimplemented")
      }
    )

    public mutating func override(
      route matchingRoute: ServerRoute.Api.Route,
      withResponse response: @escaping () async throws -> (data: Data, response: URLResponse)
    ) {
      let fulfill = expectation(description: "route")
      self.apiRequest = { [self] route in
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
      withResponse response: @escaping (Value) async throws -> (data: Data, response: URLResponse)
    ) {
      let fulfill = expectation(description: "route")
      self.apiRequest = { [self] route in
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
    apiRequest: { _ in
      (Data(), URLResponse())
    },
    authenticate: { _ in
      .init(appleReceipt: .mock, player: .blob)
    },
    baseUrl: { URL(string: "/")! },
    currentPlayer: { nil },
    logout: { },
    refreshCurrentPlayer: {
      .init(appleReceipt: .mock, player: .blob)
    },
    request: { _ in
      (Data(), URLResponse())
    },
    setBaseUrl: { _ in }
  )
}

let jsonDecoder = JSONDecoder()
