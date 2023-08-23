#if DEBUG
  import Foundation

  public func OK<A: Encodable>(
    _ value: A, encoder: JSONEncoder = .init()
  ) async throws -> (Data, URLResponse) {
    (
      try encoder.encode(value),
      HTTPURLResponse(
        url: URL(string: "/")!, statusCode: 200, httpVersion: nil, headerFields: nil)!
    )
  }

  public func OK(_ jsonObject: Any) async throws -> (Data, URLResponse) {
    (
      try JSONSerialization.data(withJSONObject: jsonObject, options: []),
      HTTPURLResponse(
        url: URL(string: "/")!, statusCode: 200, httpVersion: nil, headerFields: nil)!
    )
  }
#endif
