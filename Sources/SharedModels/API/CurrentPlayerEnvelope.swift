public struct CurrentPlayerEnvelope: Codable, Equatable, Sendable {
  public let appleReceipt: AppleVerifyReceiptResponse?
  public let player: Player

  public init(
    appleReceipt: AppleVerifyReceiptResponse?,
    player: Player
  ) {
    self.appleReceipt = appleReceipt
    self.player = player
  }
}
