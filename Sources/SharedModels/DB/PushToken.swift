import Foundation
import Tagged

public struct PushToken: Codable, Equatable {
  public typealias Arn = Tagged<((), arn: Self), String>
  public typealias Id = Tagged<Self, UUID>
  public typealias Token = Tagged<((), token: Self), String>

  public let arn: Arn
  public let authorizationStatus: PushAuthorizationStatus
  public let build: Int
  public let createdAt: Date
  public let id: Id
  public let playerId: Player.Id
  public let token: Token
}
