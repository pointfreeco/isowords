import CasePaths

#if os(Linux)
  import Csqlite3
#else
  import SQLite3
#endif

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

public final class Sqlite {
  public private(set) var handle: OpaquePointer?

  public init(path: String) throws {
    try self.validate(
      sqlite3_open_v2(
        path,
        &self.handle,
        SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE,
        nil
      )
    )
  }

  deinit {
    sqlite3_close_v2(self.handle)
  }

  public func execute(_ sql: String) throws {
    try self.validate(
      sqlite3_exec(self.handle, sql, nil, nil, nil)
    )
  }

  @discardableResult
  public func run(_ sql: String, _ bindings: Datatype...) throws -> [[Datatype]] {
    var stmt: OpaquePointer?
    try self.validate(sqlite3_prepare_v2(self.handle, sql, -1, &stmt, nil))
    defer { sqlite3_finalize(stmt) }
    for (idx, binding) in zip(Int32(1)..., bindings) {
      switch binding {
      case .null:
        try self.validate(sqlite3_bind_null(stmt, idx))
      case let .integer(value):
        try self.validate(sqlite3_bind_int(stmt, idx, value))
      case let .real(value):
        try self.validate(sqlite3_bind_double(stmt, idx, value))
      case let .text(value):
        try self.validate(sqlite3_bind_text(stmt, idx, value, -1, SQLITE_TRANSIENT))
      case let .blob(value):
        try self.validate(sqlite3_bind_blob(stmt, idx, value, -1, SQLITE_TRANSIENT))
      }
    }
    let cols = sqlite3_column_count(stmt)
    var rows: [[Datatype]] = []
    while try self.validate(sqlite3_step(stmt)) == SQLITE_ROW {
      rows.append(
        try (0..<cols).map { idx -> Datatype in
          switch sqlite3_column_type(stmt, idx) {
          case SQLITE_BLOB:
            return .blob(sqlite3_column_blob(stmt, idx).load(as: [UInt8].self))
          case SQLITE_FLOAT:
            return .real(sqlite3_column_double(stmt, idx))
          case SQLITE_INTEGER:
            return .integer(sqlite3_column_int(stmt, idx))
          case SQLITE_NULL:
            return .null
          case SQLITE_TEXT:
            return .text(String(cString: sqlite3_column_text(stmt, idx)))
          default:
            throw Error(description: "fatal")
          }
        }
      )
    }
    return rows
  }

  public var lastInsertRowid: Int64 {
    sqlite3_last_insert_rowid(self.handle)
  }

  @discardableResult
  private func validate(_ code: Int32) throws -> Int32 {
    guard code == SQLITE_OK || code == SQLITE_ROW || code == SQLITE_DONE
    else { throw Error(code: code, db: self.handle) }
    return code
  }

  @CasePathable
  @dynamicMemberLookup
  public enum Datatype: Equatable {
    case blob([UInt8])
    case integer(Int32)
    case null
    case real(Double)
    case text(String)
  }

  public struct Error: Swift.Error, Equatable {
    public var code: Int32?
    public var description: String
  }
}

extension Sqlite.Error {
  init(code: Int32, db: OpaquePointer?) {
    self.code = code
    self.description = String(cString: sqlite3_errstr(code))
  }
}
