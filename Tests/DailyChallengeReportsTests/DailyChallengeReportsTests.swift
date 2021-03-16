import DailyChallengeReports
import Either
import Overture
import Prelude
import SharedModels
import SnsClient
import XCTest

@testable import DatabaseClient

class DailyChallengeReportsTests: XCTestCase {
  func testDailyChallengeReports() throws {
    var pushes: [(targetArn: EndpointArn, payload: AnyEncodable)] = []

    try sendDailyChallengeReports(
      database: update(.failing) {
        $0.fetchDailyChallengeReport = { request in
          switch request.gameMode {
          case .timed:
            return pure([
              DatabaseClient.DailyChallengeReportResult(
                arn: "arn:aws:sns:us-east-1:1234567890:app/APNS/deadbee1",
                gameMode: .timed,
                outOf: 2,
                rank: 1,
                score: 1100
              ),
              DatabaseClient.DailyChallengeReportResult(
                arn: "arn:aws:sns:us-east-1:1234567890:app/APNS/deadbee2",
                gameMode: .timed,
                outOf: 2,
                rank: 2,
                score: 900
              ),
            ])
          case .unlimited:
            return pure([
              DatabaseClient.DailyChallengeReportResult(
                arn: "arn:aws:sns:us-east-1:1234567890:app/APNS/deadbee2",
                gameMode: .unlimited,
                outOf: 1,
                rank: 1,
                score: 3100
              ),
              DatabaseClient.DailyChallengeReportResult(
                arn: "arn:aws:sns:us-east-1:1234567890:app/APNS/deadbee3",
                gameMode: .unlimited,
                outOf: 1,
                rank: nil,
                score: nil
              ),
            ])
          }
        }
      },
      sns: update(.unimplemented) {
        $0._publish = {
          pushes.append(($0, $1))
          return pure(.init(response: .init(result: .init(messageId: "message-deadbeef"))))
        }
      }
    )
    .run.perform().unwrap()

    XCTAssertEqual(pushes.count, 3)

    let pushMap = Dictionary(grouping: pushes, by: \.targetArn)

    XCTAssertEqual(
      try JSONDecoder().decode(
        ApsPayload<PushNotificationContent>.self,
        from: JSONEncoder().encode(
          pushMap["arn:aws:sns:us-east-1:1234567890:app/APNS/deadbee1"]![0].payload)),
      ApsPayload<PushNotificationContent>(
        aps: .init(
          alert: .init(
            actionLocalizedKey: nil,
            body: """
              🥇 You ranked #1 out of 2 on yesterday’s timed challenge. Today’s is ready. Play now!
              """,
            localizedArguments: nil,
            localizedKey: nil,
            sound: nil,
            title: "Daily Challenge"
          ),
          badge: nil,
          contentAvailable: nil
        ),
        content: .dailyChallengeReport
      )
    )
    XCTAssertEqual(
      try JSONDecoder().decode(
        ApsPayload<PushNotificationContent>.self,
        from: JSONEncoder().encode(
          pushMap["arn:aws:sns:us-east-1:1234567890:app/APNS/deadbee2"]![0].payload)),
      ApsPayload<PushNotificationContent>(
        aps: .init(
          alert: .init(
            actionLocalizedKey: nil,
            body: """
              Today’s challenge is ready! Yesterday’s results:
                🥇 Unlimited: you ranked #1 out of 1.
                🥈 Timed: #2 out of 2.
              Play again today!
              """,
            localizedArguments: nil,
            localizedKey: nil,
            sound: nil,
            title: "Daily Challenge"
          ),
          badge: nil,
          contentAvailable: nil
        ),
        content: .dailyChallengeReport
      )
    )
    XCTAssertEqual(
      try JSONDecoder().decode(
        ApsPayload<PushNotificationContent>.self,
        from: JSONEncoder().encode(
          pushMap["arn:aws:sns:us-east-1:1234567890:app/APNS/deadbee3"]![0].payload)),
      ApsPayload<PushNotificationContent>(
        aps: .init(
          alert: .init(
            actionLocalizedKey: nil,
            body: """
              Today’s challenge is ready. Play now!
              """,
            localizedArguments: nil,
            localizedKey: nil,
            sound: nil,
            title: "Daily Challenge"
          ),
          badge: nil,
          contentAvailable: nil
        ),
        content: .dailyChallengeReport
      )
    )
  }
}
