import Combine
import CombineHelpers
import ComposableArchitecture
import Foundation

public struct FileClient {
  public var delete: (String) -> Effect<Never, Error>
  public var load: (String) -> Effect<Data, Error>
  public var save: (String, Data) -> Effect<Never, Error>

  public func load<A: Decodable>(
    _ type: A.Type, from fileName: String
  ) -> Effect<Result<A, Error>, Never> {
    self.load(fileName)
      .decode(type: A.self, decoder: JSONDecoder())
      .catchToEffect()
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
}
