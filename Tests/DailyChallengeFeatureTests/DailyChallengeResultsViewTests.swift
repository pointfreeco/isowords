import ComposableArchitecture
import DailyChallengeFeature
import LeaderboardFeature
import SharedModels
import SnapshotTesting
import Styleguide
import XCTest

class DailyChallengeResultsViewTests: XCTestCase {
  override func setUpWithError() throws {
    try super.setUpWithError()
    try XCTSkipIf(!Styleguide.registerFonts())
    diffTool = "ksdiff"
//    isRecording = true
  }

  func testDefault() {
    assertSnapshot(
      matching: DailyChallengeResultsView(
        store: Store(
          initialState: DailyChallengeResults.State(
            leaderboardResults: .init(
              gameMode: .timed,
              resultEnvelope: .init(
                outOf: 2_000,
                results: (1...10).map { idx in
                  .init(
                    denseRank: idx,
                    id: .init(),
                    isYourScore: idx == 5,
                    rank: idx,
                    score: 5_000 - idx * 250,
                    subtitle: nil,
                    title: "Blob \(idx)"
                  )
                }
              ),
              timeScope: 1
            )
          )
        ) {

        }
      ),
      as: .image(perceptualPrecision: 0.98, layout: .device(config: .iPhoneXsMax))
    )
  }

  func testTimeScopeOpenedLoading() {
    assertSnapshot(
      matching: DailyChallengeResultsView(
        store: Store(
          initialState: DailyChallengeResults.State(
            leaderboardResults: .init(
              gameMode: .timed,
              isTimeScopeMenuVisible: true,
              resultEnvelope: .init(
                outOf: 2_000,
                results: (1...10).map { idx in
                  .init(
                    denseRank: idx,
                    id: .init(),
                    isYourScore: idx == 5,
                    rank: idx,
                    score: 5_000 - idx * 250,
                    subtitle: nil,
                    title: "Blob \(idx)"
                  )
                }
              ),
              timeScope: 1
            )
          )
        ) {

        }
      ),
      as: .image(perceptualPrecision: 0.98, layout: .device(config: .iPhoneXsMax))
    )
  }

  func testTimeScopeOpened() {
    let historyResults = (1...30).map { idx in
      DailyChallengeHistoryResponse.Result(
        createdAt: Date.mock.addingTimeInterval(Double(-86_400 * idx)),
        gameNumber: DailyChallenge.GameNumber(rawValue: idx),
        isToday: idx == 1,
        rank: idx
      )
    }

    assertSnapshot(
      matching: DailyChallengeResultsView(
        store: Store(
          initialState: DailyChallengeResults.State(
            history: .init(
              results: historyResults
            ),
            leaderboardResults: .init(
              gameMode: .timed,
              isTimeScopeMenuVisible: true,
              resultEnvelope: .init(
                outOf: 2_000,
                results: (1...10).map { idx in
                  .init(
                    denseRank: idx,
                    id: .init(),
                    isYourScore: idx == 5,
                    rank: idx,
                    score: 5_000 - idx * 250,
                    subtitle: nil,
                    title: "Blob \(idx)"
                  )
                }
              ),
              timeScope: 1
            )
          )
        ) {
          
        }
      ),
      as: .image(perceptualPrecision: 0.98, layout: .device(config: .iPhoneXsMax))
    )
  }
}
