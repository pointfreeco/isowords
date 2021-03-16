import ApplicativeRouter
import Foundation

extension PartialIso where A == String, B == Data {
  static let base64 = Self(
    apply: { Data(base64Encoded: $0) },
    unapply: { $0.base64EncodedString() }
  )
}
