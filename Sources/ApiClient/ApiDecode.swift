import Combine
import ComposableArchitecture
import SharedModels

extension Publisher where Output == Data, Failure == URLError {
  public func apiDecode<A: Decodable>(
    as type: A.Type,
    file: StaticString = #file,
    line: UInt = #line
  ) -> Effect<A, ApiError> {
    self
      .mapError { ApiError(error: $0, file: file, line: line) }
      .flatMap { data -> AnyPublisher<A, ApiError> in
        do {
          return try Just(jsonDecoder.decode(A.self, from: data))
            .setFailureType(to: ApiError.self)
            .eraseToAnyPublisher()
        } catch let decodingError {
          do {
            return try Fail(
              error: jsonDecoder.decode(ApiError.self, from: data)
            ).eraseToAnyPublisher()
          } catch {
            return Fail(error: ApiError(error: decodingError)).eraseToAnyPublisher()
          }
        }
      }
      .eraseToEffect()
  }
}
