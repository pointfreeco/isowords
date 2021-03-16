public struct VerifyReceiptEnvelope: Codable, Equatable {
  public let verifiedProductIds: [String]

  public init(verifiedProductIds: [String]) {
    self.verifiedProductIds = verifiedProductIds
  }
}
