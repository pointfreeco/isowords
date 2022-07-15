import Combine
import CombineHelpers
import ComposableArchitecture
import Foundation

public struct FileClient {
  @available(*, deprecated) public var delete: (String) -> Effect<Never, Error>
  public var deleteAsync: @Sendable (String) async throws -> Void
  @available(*, deprecated) public var load: (String) -> Effect<Data, Error>
  public var loadAsync: @Sendable (String) async throws -> Data
  @available(*, deprecated) public var save: (String, Data) -> Effect<Never, Error>
  public var saveAsync: @Sendable (String, Data) async throws -> Void

  public func load<A: Decodable>(
    _ type: A.Type, from fileName: String
  ) -> Effect<Result<A, NSError>, Never> {
    self.load(fileName)
      .decode(type: A.self, decoder: JSONDecoder())
      .mapError { $0 as NSError }
      .catchToEffect()
  }

  public func loadAsync<A: Decodable>(_ type: A.Type, from fileName: String) async throws -> A {
    try await JSONDecoder().decode(A.self, from: self.loadAsync(fileName))
  }

  public func save<A: Encodable>(
    _ data: A, to fileName: String, on queue: AnySchedulerOf<DispatchQueue>
  ) -> Effect<Never, Never> {
    Just(data)
      .subscribe(on: queue)
      .encode(encoder: JSONEncoder())
      .flatMap { data in self.save(fileName, data) }
      .ignoreFailure()
      .eraseToEffect()
  }

  public func saveAsync<A: Encodable>(_ data: A, to fileName: String) async throws -> Void {
    try await self.saveAsync(fileName, JSONEncoder().encode(data))
  }
}
