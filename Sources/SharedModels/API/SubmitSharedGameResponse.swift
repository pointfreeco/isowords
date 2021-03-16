import Foundation
import Tagged

public struct SubmitSharedGameResponse: Codable, Equatable {
  public let code: SharedGame.Code
  public let id: SharedGame.Id
  public let url: String

  public init(
    code: SharedGame.Code,
    id: SharedGame.Id,
    url: String
  ) {
    self.code = code
    self.id = id
    self.url = url
  }
}
