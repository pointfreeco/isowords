public struct AnyEncodable: Encodable {
  let _encode: (Encoder) throws -> Void

  public init<Value: Encodable>(_ value: Value) {
    self._encode = { try value.encode(to: $0) }
  }

  public func encode(to encoder: Encoder) throws {
    try self._encode(encoder)
  }
}
