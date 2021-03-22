import DailyChallengeFeature
import SharedModels
import SnapshotTesting
import Styleguide
import XCTest

class DailyChallengeViewTests: XCTestCase {
  override class func setUp() {
    super.setUp()
    Styleguide.registerFonts()
    SnapshotTesting.diffTool = "ksdiff"
  }

  override func setUpWithError() throws {
    try super.setUpWithError()
    try XCTSkipIf(!Styleguide.registerFonts())
//    isRecording = true
  }

  func testDefault() {
    assertSnapshot(
      matching: DailyChallengeView(
        store: .init(
          initialState: .init(),
          reducer: .empty,
          environment: ()
        )
      )
      .environment(\.date) { .mock },
      as: .image(layout: .device(config: .iPhoneXsMax))
    )
  }

  func testTimedGamePlayed_UnlimitedGameResumable() {
    assertSnapshot(
      matching: DailyChallengeView(
        store: .init(
          initialState: .init(
            dailyChallenges: [
              .init(
                dailyChallenge: .init(
                  endsAt: .mock,
                  gameMode: .timed,
                  id: .init(rawValue: .dailyChallengeId),
                  language: .en
                ),
                yourResult: .init(outOf: 3_000, rank: 20, score: 2_000, started: true)
              ),
              .init(
                dailyChallenge: .init(
                  endsAt: .mock,
                  gameMode: .unlimited,
                  id: .init(rawValue: .dailyChallengeId),
                  language: .en
                ),
                yourResult: .init(outOf: 5_000, rank: nil, score: nil)
              ),
            ],
            inProgressDailyChallengeUnlimited: .init(
              cubes: .mock,
              gameContext: .dailyChallenge(.init(rawValue: .dailyChallengeId)),
              gameMode: .unlimited,
              gameStartTime: .mock,
              moves: [.mock],
              secondsPlayed: 0
            ),
            userNotificationSettings: .init(authorizationStatus: .notDetermined)
          ),
          reducer: .empty,
          environment: ()
        )
      )
      .environment(\.date) { .mock },
      as: .image(layout: .device(config: .iPhoneXsMax))
    )
  }
}
