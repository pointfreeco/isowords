import SnapshotTesting
import SnsClient
import XCTest

class SnsClientTests: XCTestCase {
  func testApsPayloadEncoding_NoContent() {
    let apsPayload_NoContent = ApsPayload(
      aps: .init(
        alert: .init(
          actionLocalizedKey: "action",
          body: "Blob reacted to your move: 😛",
          localizedArguments: ["😛"],
          localizedKey: "key",
          sound: "boop.wav",
          title: "isowords"
        ),
        badge: 1,
        contentAvailable: true
      )
    )
    _assertInlineSnapshot(matching: apsPayload_NoContent, as: .json, with: """
      {
        "aps" : {
          "alert" : {
            "action-loc-key" : "action",
            "body" : "Blob reacted to your move: 😛",
            "loc-args" : [
              "😛"
            ],
            "loc-key" : "key",
            "sound" : "boop.wav",
            "title" : "isowords"
          },
          "badge" : 1,
          "content-available" : true
        }
      }
      """
    )

    struct Content: Encodable {
      let route: Route

      struct Route: Encodable {
        let dailyChallengeId: String
        let localPlayerIndex: Int
      }
    }
    let apsPayload_WithContent = ApsPayload(
      aps: .init(
        alert: .init(
          body: "Blob reacted to your move: 😛",
          title: "isowords"
        )
      ),
      content: Content(route: .init(dailyChallengeId: "deadbeef", localPlayerIndex: 1))
    )
    _assertInlineSnapshot(matching: apsPayload_WithContent, as: .json, with: """
      {
        "aps" : {
          "alert" : {
            "body" : "Blob reacted to your move: 😛",
            "title" : "isowords"
          }
        },
        "route" : {
          "dailyChallengeId" : "deadbeef",
          "localPlayerIndex" : 1
        }
      }
      """
    )
  }
}
