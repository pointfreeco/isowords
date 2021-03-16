import Foundation
import Tagged

public struct AppleReceipt: Codable, Equatable {
  public typealias Id = Tagged<Self, UUID>

  public var createdAt: Date
  public var id: Id
  public var playerId: Player.Id
  public var receipt: AppleVerifyReceiptResponse

  public init(
    createdAt: Date,
    id: Id,
    playerId: Player.Id,
    receipt: AppleVerifyReceiptResponse
  ) {
    self.createdAt = createdAt
    self.id = id
    self.playerId = playerId
    self.receipt = receipt
  }
}

#if DEBUG
  extension AppleReceipt {
    public static let mock = Self(
      createdAt: .mock,
      id: .init(rawValue: .deadbeef),
      playerId: .init(rawValue: .deadbeef),
      receipt: .mock
    )
  }
#endif
