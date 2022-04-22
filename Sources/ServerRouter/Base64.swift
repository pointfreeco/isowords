import Foundation
import Parsing

extension Conversion where Self == Base64 {
  static var base64: Self { .init() }
}

extension Conversion where Output == String {
  var base64: Conversions.Map<Self, Base64> { self.map(.base64) }
}

struct Base64: Conversion {
  struct DecodingError: Error {}

  func apply(_ input: String) throws -> Data {
    guard let data = Data(base64Encoded: input)
    else { throw DecodingError() }
    return data
  }

  func unapply(_ output: Data) throws -> String {
    output.base64EncodedString()
  }
}
