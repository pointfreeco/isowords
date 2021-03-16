public struct CurrentPlayerEnvelope: Codable, Equatable {
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
