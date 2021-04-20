import DatabaseClient
import Either
import FirstPartyMocks
import Overture
import Prelude
import RunnerTasks
import SharedModels
import SiteMiddleware
import SnsClient
import XCTest

final class RunnerTests: XCTestCase {
  func testSendDailyChallengeEndsSoonNotifications() throws {
    let now = Date.mock

    var targetArn: String?
    var payload: AnyEncodable?

    let environment = update(ServerEnvironment.failing) {
      $0.database.fetchActiveDailyChallengeArns = {
        pure([DatabaseClient.DailyChallengeArn(arn: "arn-deadbeef", endsAt: now + 60 * 60)])
      }
      $0.date = { now }
      $0.snsClient._publish = {
        targetArn = $0.rawValue
        payload = $1
        return pure(.init(response: .init(result: .init(messageId: "message-deadbeef"))))
      }
    }

    _ = try sendDailyChallengeEndsSoonNotifications(environment: environment)
      .run
      .perform()
      .unwrap()

    XCTAssertEqual(targetArn, "arn-deadbeef")

    XCTAssertEqual(
      try JSONDecoder().decode(
        ApsPayload<PushNotificationContent>.self, from: JSONEncoder().encode(payload)),
      ApsPayload<PushNotificationContent>(
        aps: .init(
          alert: .init(
            actionLocalizedKey: nil,
            body: "⏳ The daily challenge ends in 60 minutes! Finish your game before it’s over.",
            localizedArguments: nil,
            localizedKey: nil,
            sound: nil,
            title: "Daily Challenge Ends Soon"
          ),
          badge: nil,
          contentAvailable: nil
        ),
        content: .dailyChallengeEndsSoon
      )
    )
  }
}
