#if DEBUG
  import Foundation

  public func ok<A: Encodable>(
    _ value: A,
    encoder: JSONEncoder = .init()
  ) -> (data: Data, response: URLResponse) {
    (
      try! encoder.encode(value),
      HTTPURLResponse(
        url: URL(string: "/")!, statusCode: 200, httpVersion: nil, headerFields: nil)!
    )
  }

  public func ok(
    _ jsonObject: Any
  ) -> (date: Data, response: URLResponse) {
    (
      try! JSONSerialization.data(withJSONObject: jsonObject, options: []),
      HTTPURLResponse(
        url: URL(string: "/")!, statusCode: 200, httpVersion: nil, headerFields: nil)!
    )
  }
#endif
