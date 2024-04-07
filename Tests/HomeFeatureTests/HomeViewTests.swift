import ClientModels
import ComposableArchitecture
import ComposableGameCenter
import HomeFeature
import Overture
import SharedModels
import SnapshotTesting
import Styleguide
import XCTest

class HomeFeatureTests: XCTestCase {
  override class func setUp() {
    super.setUp()
    SnapshotTesting.diffTool = "ksdiff"
  }

  override func setUpWithError() throws {
    try super.setUpWithError()
    try XCTSkipIf(!Styleguide.registerFonts())
//    isRecording = true
  }

  func testBasics() {
    assertSnapshot(
      matching: HomeView(
        store: Store(
          initialState: Home.State(
            dailyChallenges: [
              .init(
                dailyChallenge: .init(
                  endsAt: .mock,
                  gameMode: .timed,
                  id: .init(rawValue: .dailyChallengeId),
                  language: .en
                ),
                yourResult: .init(outOf: 4_000, rank: nil, score: nil, started: false)
              )
            ],
            weekInReview: .init(
              ranks: [
                .init(gameMode: .timed, outOf: 2_000, rank: 100),
                .init(gameMode: .unlimited, outOf: 1_500, rank: 200),
              ],
              word: .init(letters: "Jazziest", score: 1400)
            )
          )
        ) {
        }
      )
      .environment(\.date, { .mock - 2*60*60 }),
      as: .image(
        perceptualPrecision: 0.98,
        layout: .device(
          config: update(.iPhoneXsMax) {
            $0.size?.height += 200
          }
        )
      )
    )
  }

  func testActiveGames_DailyChallenge_Solo() {
    assertSnapshot(
      matching: HomeView(
        store: Store(
          initialState: Home.State(
            dailyChallenges: []
          )
        ) {
        }
      )
      .environment(\.date, { .mock - 2*60*60 }),
      as: .image(perceptualPrecision: 0.98, layout: .device(config: .iPhoneXsMax))
    )
  }

  func testActiveGames_Multiplayer() {
    assertSnapshot(
      matching: HomeView(
        store: Store(
          initialState: Home.State(
            dailyChallenges: [],
            turnBasedMatches: [
              .init(
                id: "1",
                isYourTurn: true,
                lastPlayedAt: .mock,
                now: .mock,
                playedWord: PlayedWord(
                  isYourWord: false,
                  reactions: [0: .angel],
                  score: 120,
                  word: "HELLO"
                ),
                status: .open,
                theirIndex: 1,
                theirName: "Blob"
              ),
              .init(
                id: "2",
                isYourTurn: false,
                lastPlayedAt: .mock,
                now: .mock,
                playedWord: PlayedWord(
                  isYourWord: true,
                  reactions: [0: .angel],
                  score: 420,
                  word: "GOODBYE"
                ),
                status: .open,
                theirIndex: 0,
                theirName: "Blob"
              ),
            ]
          )
        ) {
        }
      )
      .environment(\.date, { .mock - 2*60*60 }),
      as: .image(perceptualPrecision: 0.98, layout: .device(config: .iPhoneXsMax))
    )
  }

  func testActiveGames_StaleGame() {
    assertSnapshot(
      matching: HomeView(
        store: Store(
          initialState: Home.State(
            dailyChallenges: [],
            turnBasedMatches: [
              .init(
                id: "2",
                isYourTurn: false,
                lastPlayedAt: Date.mock.advanced(by: -60 * 60 * 24 * 3),
                now: .mock,
                playedWord: PlayedWord(
                  isYourWord: true,
                  reactions: [0: .angel],
                  score: 420,
                  word: "GOODBYE"
                ),
                status: .open,
                theirIndex: 0,
                theirName: "Blob"
              ),
            ]
          )
        ) {
        }
      )
      .environment(\.date, { .mock - 2*60*60 }),
      as: .image(perceptualPrecision: 0.98, layout: .device(config: .iPhoneXsMax))
    )
  }
}
