import DependenciesMacros
import Foundation

@DependencyClient
public struct FileClient {
  public var delete: @Sendable (String) async throws -> Void
  public var load: @Sendable (String) async throws -> Data
  public var save: @Sendable (String, Data) async throws -> Void

  public func load<A: Decodable>(_ type: A.Type, from fileName: String) async throws -> A {
    try await JSONDecoder().decode(A.self, from: self.load(fileName))
  }

  public func save<A: Encodable>(_ data: A, to fileName: String) async throws {
    try await self.save(fileName, JSONEncoder().encode(data))
  }
}
