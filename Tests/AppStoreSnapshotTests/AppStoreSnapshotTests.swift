import ActiveGamesFeature
import ClientModels
import ComposableArchitecture
import ComposableGameCenter
import CubeCore
import DailyChallengeFeature
import GameFeature
import GameKit
import Gen
import HomeFeature
import LeaderboardFeature
import Overture
import PuzzleGen
import SharedModels
import SnapshotTesting
import Styleguide
import SwiftUI
import XCTest

struct SnapshotConfig {
  let adaptiveSize: AdaptiveSize
  let deviceState: DeviceState
  let viewImageConfig: ViewImageConfig
}

let appStoreViewConfigs: [String: SnapshotConfig] = [
  "iPhone_5_5": .init(adaptiveSize: .medium, deviceState: .phone, viewImageConfig: .iPhone8Plus),
  "iPhone_6_5": .init(adaptiveSize: .large, deviceState: .phone, viewImageConfig: .iPhoneXsMax),
  "iPad_12_9": .init(
    adaptiveSize: .large, deviceState: .pad, viewImageConfig: .iPadPro12_9(.portrait)),
]

class AppStoreSnapshotTests: XCTestCase {
  static override func setUp() {
    super.setUp()
    SnapshotTesting.diffTool = "ksdiff"
  }

  override func setUpWithError() throws {
    try super.setUpWithError()
    try XCTSkipIf(!Styleguide.registerFonts())
//    isRecording = true
  }

  override func tearDown() {
    isRecording = false
    super.tearDown()
  }

  func test_1_SoloGame() {
    assertAppStoreSnapshots(
      for: gameplayAppStoreView,
      description: {
        Text("Find as many words as you can ").foregroundColor(Color.black.opacity(0.4))
          + Text("on a vanishing cube").foregroundColor(Color.black)
      },
      backgroundColor: .isowordsYellow,
      colorScheme: .dark,
      precision: 0.999 // NB: gradient bloom can render slightly differently each run
    )
  }

  func test_2_TurnBasedGame() {
    assertAppStoreSnapshots(
      for: turnBasedAppStoreView,
      description: {
        Text("You can play\nsolo or ").foregroundColor(Color.black.opacity(0.4))
          + Text("against\na friend").foregroundColor(Color.black)
      },
      backgroundColor: .hex(0xEDBC8A),
      colorScheme: .light
    )
  }

  func test_3_DailyChallengeResults() {
    assertAppStoreSnapshots(
      for: dailyChallengeAppStoreView,
      description: {
        Text("Or compete in the\n").foregroundColor(Color.black.opacity(0.4))
          + Text("daily challenge").foregroundColor(Color.black)
      },
      backgroundColor: .hex(0xE79273),
      colorScheme: .dark
    )
  }

  func test_4_Leaderboards() {
    assertAppStoreSnapshots(
      for: leaderboardAppStoreView,
      description: {
        Text("Longer words score higher. ").foregroundColor(Color.black.opacity(0.4))
          + Text("Show off your achievements!").foregroundColor(Color.black)
      },
      backgroundColor: .isowordsRed,
      colorScheme: .light
    )
  }

  func test_5_Home() {
    assertAppStoreSnapshots(
      for: homeAppStoreView,
      description: {
        Text("The cult classic is back and waiting for you!")
      },
      backgroundColor: .isowordsBlack,
      colorScheme: .dark
    )
  }
}
