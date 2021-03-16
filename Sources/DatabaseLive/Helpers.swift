import Either
import PostgresKit
import SharedModels
import Tagged

extension EitherIO where E == Error {
  init(_ eventLoopFuture: @escaping @autoclosure () -> EventLoopFuture<A>) {
    self.init(
      run: .init { callback in
        eventLoopFuture()
          .whenComplete {
            result in callback(.init(result: result))
          }
      }
    )
  }
}

extension PostgresDatabase {
  func run(_ query: SQLQueryString) -> EitherIO<Error, Void> {
    EitherIO(self.sql().raw(query).run())
  }
}

extension SQLRawBuilder {
  func first<D>(decoding: D.Type) -> EitherIO<Error, D?> where D: Decodable {
    .init(self.first(decoding: D.self))
  }

  func first() -> EitherIO<Error, SQLRow?> {
    .init(self.first())
  }

  func all<D>(decoding: D.Type) -> EitherIO<Error, [D]> where D: Decodable {
    .init(self.all(decoding: D.self))
  }

  func run() -> EitherIO<Error, Void> {
    .init(self.run())
  }
}

extension EventLoopGroupConnectionPool where Source == PostgresConnectionSource {
  var sqlDatabase: SQLDatabase {
    self.database(logger: logger).sql()
  }
}

private let logger = Logger(label: "Postgres")

extension Either where L: Error {
  init(result: Result<R, L>) {
    switch result {
    case let .success(value):
      self = .right(value)
    case let .failure(error):
      self = .left(error)
    }
  }
}

extension Three: PostgresDataConvertible where Element: Codable {
}

extension Three: PostgresJSONBCodable where Element: Codable {
}

extension Moves: PostgresJSONBCodable {
}

extension Tagged: PostgresDataConvertible where RawValue: PostgresDataConvertible {
}
