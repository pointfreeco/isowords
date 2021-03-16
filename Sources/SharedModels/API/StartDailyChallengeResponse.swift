import Foundation
import Tagged

public struct StartDailyChallengeResponse: Codable, Equatable {
  public let dailyChallenge: DailyChallenge
  public let dailyChallengePlayId: DailyChallengePlay.Id

  public init(
    dailyChallenge: DailyChallenge,
    dailyChallengePlayId: DailyChallengePlay.Id
  ) {
    self.dailyChallenge = dailyChallenge
    self.dailyChallengePlayId = dailyChallengePlayId
  }
}
