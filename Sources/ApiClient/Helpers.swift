#if DEBUG
  import ComposableArchitecture
  import Foundation

  extension Effect where Output == (data: Data, response: URLResponse), Failure == URLError {
    public static func ok<A: Encodable>(
      _ value: A,
      encoder: JSONEncoder = .init()
    ) -> Self {
      .init(
        value: (
          try! encoder.encode(value),
          HTTPURLResponse(
            url: URL(string: "/")!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        )
      )
    }

    public static func ok(
      _ jsonObject: Any
    ) -> Self {
      .init(
        value: (
          try! JSONSerialization.data(withJSONObject: jsonObject, options: []),
          HTTPURLResponse(
            url: URL(string: "/")!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        )
      )
    }
  }
#endif
