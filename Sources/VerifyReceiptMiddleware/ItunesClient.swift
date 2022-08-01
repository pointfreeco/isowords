import Either
import Foundation
import ServerTestHelpers
import SharedModels
import XCTestDynamicOverlay

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

public struct ItunesClient {
  public var verify:
    (Data, AppleVerifyReceiptResponse.Environment) -> EitherIO<
      Error, (AppleVerifyReceiptResponse, Data)
    >

  public init(
    verify: @escaping (Data, AppleVerifyReceiptResponse.Environment) -> EitherIO<
      Error, (AppleVerifyReceiptResponse, Data)
    >
  ) {
    self.verify = verify
  }
}

extension ItunesClient {
  public static let live = Self(
    verify: { data, environment in
      .init(
        run: .init { callback in
          let payload = ["receipt-data": data.base64EncodedString()]
          var request: URLRequest
          switch environment {
          case .sandbox:
            request = URLRequest(
              url: URL(string: "https://sandbox.itunes.apple.com/verifyReceipt")!)
          case .production:
            request = URLRequest(url: URL(string: "https://buy.itunes.apple.com/verifyReceipt")!)
          }
          request.httpMethod = "POST"
          request.httpBody = try? encoder.encode(payload)
          URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
              callback(.left(error))
            } else if let data = data,
              let response = try? decoder.decode(AppleVerifyReceiptResponse.self, from: data)
            {
              callback(.right((response, data)))
            } else {
              callback(.left(URLError.init(.badServerResponse)))
            }
          }
          .resume()
        }
      )
    }
  )
}

#if DEBUG
  extension ItunesClient {
    public static let unimplemented = Self(
      verify: { _, _ in
        .unimplemented("\(Self.self).verify")
      }
    )
  }
#endif

private let decoder = JSONDecoder()
private let encoder = JSONEncoder()
