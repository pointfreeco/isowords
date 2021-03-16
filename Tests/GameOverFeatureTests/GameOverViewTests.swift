import ClientModels
import ComposableGameCenter
@testable import GameOverFeature
import SharedModels
import SharedSwiftUIEnvironment
import SnapshotTesting
import Styleguide
import XCTest

class GameOverViewTests: XCTestCase {
  override func setUpWithError() throws {
    try super.setUpWithError()
    try XCTSkipIf(!Styleguide.registerFonts())
//    isRecording = true
  }

  func testSolo() {
    assertSnapshot(
      matching: GameOverView(
        store: .init(
          initialState: .init(
            completedGame: .init(
              cubes: .mock,
              gameContext: .solo,
              gameMode: .timed,
              gameStartTime: .mock,
              language: .en,
              moves: [.mock, .mock, .mock, .mock, .mock],
              secondsPlayed: 0
            ),
            isDemo: false,
            summary: .leaderboard([
              .allTime: .init(outOf: 10_000, rank: 200),
              .lastWeek: .init(outOf: 6_000, rank: 100),
              .lastDay: .init(outOf: 3_000, rank: 20),
            ])
          ),
          reducer: .empty,
          environment: ()
        )
      ),
      as: .image(layout: .device(config: .iPhoneXsMax))
    )
  }

  func testDailyChallenge() {
    assertSnapshot(
      matching: GameOverView(
        store: .init(
          initialState: .init(
            completedGame: .fetchedResponse,
            isDemo: false,
            summary: .dailyChallenge(
              .init(
                outOf: 3_000,
                rank: 100,
                score: 4_000
              )
            )
          ),
          reducer: .empty,
          environment: ()
        )
      ),
      as: .image(layout: .device(config: .iPhoneXsMax))
    )
  }

  func testTurnBased() {
    var completedGame = CompletedGame.turnBased
    completedGame.cubes = turnBasedGame.puzzle
    completedGame.moves = turnBasedGame.moves

    assertSnapshot(
      matching: GameOverView(
        store: .init(
          initialState: .init(
            completedGame: completedGame,
            isDemo: false,
            turnBasedContext: .init(
              localPlayer: .authenticated,
              match: .mock,
              metadata: .init(playerIndexToId: [:])
            )
          ),
          reducer: .empty,
          environment: ()
        )
      )
      .environment(\.yourImage, UIImage(named: "you", in: .module, with: nil))
      .environment(\.opponentImage, UIImage(named: "opponent", in: .module, with: nil)),
      as: .image(layout: .device(config: .iPhoneXsMax))
    )
  }
}

let turnBasedGame = try! JSONDecoder().decode(
  FetchVocabWordResponse.self,
  from: Data(
    #"""
    {"puzzle":[[[{"top": {"side": 0, "letter": "N"}, "left": {"side": 1, "letter": "M"}, "right": {"side": 2, "letter": "B"}}, {"top": {"side": 0, "letter": "O"}, "left": {"side": 1, "letter": "S"}, "right": {"side": 2, "letter": "H"}}, {"top": {"side": 0, "letter": "H"}, "left": {"side": 1, "letter": "M"}, "right": {"side": 2, "letter": "N"}}], [{"top": {"side": 0, "letter": "D"}, "left": {"side": 1, "letter": "N"}, "right": {"side": 2, "letter": "M"}}, {"top": {"side": 0, "letter": "R"}, "left": {"side": 1, "letter": "N"}, "right": {"side": 2, "letter": "T"}}, {"top": {"side": 0, "letter": "N"}, "left": {"side": 1, "letter": "U"}, "right": {"side": 2, "letter": "O"}}], [{"top": {"side": 0, "letter": "I"}, "left": {"side": 1, "letter": "P"}, "right": {"side": 2, "letter": "O"}}, {"top": {"side": 0, "letter": "F"}, "left": {"side": 1, "letter": "E"}, "right": {"side": 2, "letter": "E"}}, {"top": {"side": 0, "letter": "U"}, "left": {"side": 1, "letter": "T"}, "right": {"side": 2, "letter": "R"}}]], [[{"top": {"side": 0, "letter": "D"}, "left": {"side": 1, "letter": "H"}, "right": {"side": 2, "letter": "E"}}, {"top": {"side": 0, "letter": "E"}, "left": {"side": 1, "letter": "L"}, "right": {"side": 2, "letter": "I"}}, {"top": {"side": 0, "letter": "F"}, "left": {"side": 1, "letter": "S"}, "right": {"side": 2, "letter": "N"}}], [{"top": {"side": 0, "letter": "V"}, "left": {"side": 1, "letter": "H"}, "right": {"side": 2, "letter": "P"}}, {"top": {"side": 0, "letter": "C"}, "left": {"side": 1, "letter": "E"}, "right": {"side": 2, "letter": "I"}}, {"top": {"side": 0, "letter": "R"}, "left": {"side": 1, "letter": "N"}, "right": {"side": 2, "letter": "M"}}], [{"top": {"side": 0, "letter": "E"}, "left": {"side": 1, "letter": "S"}, "right": {"side": 2, "letter": "A"}}, {"top": {"side": 0, "letter": "I"}, "left": {"side": 1, "letter": "T"}, "right": {"side": 2, "letter": "O"}}, {"top": {"side": 0, "letter": "P"}, "left": {"side": 1, "letter": "R"}, "right": {"side": 2, "letter": "Y"}}]], [[{"top": {"side": 0, "letter": "A"}, "left": {"side": 1, "letter": "N"}, "right": {"side": 2, "letter": "QU"}}, {"top": {"side": 0, "letter": "E"}, "left": {"side": 1, "letter": "V"}, "right": {"side": 2, "letter": "L"}}, {"top": {"side": 0, "letter": "B"}, "left": {"side": 1, "letter": "U"}, "right": {"side": 2, "letter": "U"}}], [{"top": {"side": 0, "letter": "N"}, "left": {"side": 1, "letter": "J"}, "right": {"side": 2, "letter": "O"}}, {"top": {"side": 0, "letter": "E"}, "left": {"side": 1, "letter": "A"}, "right": {"side": 2, "letter": "F"}}, {"top": {"side": 0, "letter": "E"}, "left": {"side": 1, "letter": "M"}, "right": {"side": 2, "letter": "T"}}], [{"top": {"side": 0, "letter": "V"}, "left": {"side": 1, "letter": "N"}, "right": {"side": 2, "letter": "B"}}, {"top": {"side": 0, "letter": "S"}, "left": {"side": 1, "letter": "W"}, "right": {"side": 2, "letter": "H"}}, {"top": {"side": 0, "letter": "G"}, "left": {"side": 1, "letter": "M"}, "right": {"side": 2, "letter": "L"}}]]],"moves":[{"type": {"removedCube": {"x": 2, "y": 2, "z": 2}}, "score": 0, "playedAt": 0, "playerIndex": 0}, {"type": {"playedWord": [{"side": 1, "index": {"x": 2, "y": 2, "z": 1}}, {"side": 0, "index": {"x": 1, "y": 2, "z": 1}}, {"side": 0, "index": {"x": 2, "y": 2, "z": 0}}, {"side": 0, "index": {"x": 1, "y": 2, "z": 0}}, {"side": 0, "index": {"x": 2, "y": 2, "z": 1}}]}, "score": 130, "playedAt": 0, "playerIndex": 0}, {"type": {"playedWord": [{"side": 2, "index": {"x": 2, "y": 2, "z": 0}}, {"side": 2, "index": {"x": 2, "y": 1, "z": 0}}, {"side": 2, "index": {"x": 2, "y": 0, "z": 1}}, {"side": 2, "index": {"x": 2, "y": 1, "z": 2}}, {"side": 0, "index": {"x": 2, "y": 1, "z": 2}}, {"side": 1, "index": {"x": 1, "y": 2, "z": 2}}]}, "score": 216, "playedAt": 0, "playerIndex": 1}, {"type": {"playedWord": [{"side": 1, "index": {"x": 2, "y": 2, "z": 1}}, {"side": 0, "index": {"x": 1, "y": 2, "z": 1}}, {"side": 0, "index": {"x": 2, "y": 2, "z": 1}}, {"side": 2, "index": {"x": 2, "y": 2, "z": 1}}, {"side": 2, "index": {"x": 2, "y": 1, "z": 1}}, {"side": 2, "index": {"x": 2, "y": 0, "z": 2}}, {"side": 2, "index": {"x": 2, "y": 0, "z": 1}}]}, "score": 560, "playedAt": 0, "playerIndex": 0}, {"type": {"playedWord": [{"side": 2, "index": {"x": 2, "y": 1, "z": 1}}, {"side": 2, "index": {"x": 2, "y": 0, "z": 1}}, {"side": 2, "index": {"x": 2, "y": 0, "z": 2}}, {"side": 2, "index": {"x": 2, "y": 1, "z": 2}}, {"side": 0, "index": {"x": 2, "y": 1, "z": 2}}, {"side": 2, "index": {"x": 1, "y": 2, "z": 2}}]}, "score": 288, "playedAt": 0, "playerIndex": 1}, {"type": {"removedCube": {"x": 1, "y": 2, "z": 2}}, "score": 0, "playedAt": 0, "playerIndex": 0}, {"type": {"playedWord": [{"side": 0, "index": {"x": 0, "y": 2, "z": 1}}, {"side": 0, "index": {"x": 0, "y": 2, "z": 2}}, {"side": 1, "index": {"x": 0, "y": 2, "z": 2}}, {"side": 1, "index": {"x": 0, "y": 1, "z": 2}}, {"side": 0, "index": {"x": 1, "y": 1, "z": 2}}, {"side": 0, "index": {"x": 2, "y": 1, "z": 2}}]}, "score": 216, "playedAt": 0, "playerIndex": 0}, {"type": {"playedWord": [{"side": 2, "index": {"x": 2, "y": 2, "z": 1}}, {"side": 1, "index": {"x": 2, "y": 1, "z": 1}}, {"side": 0, "index": {"x": 1, "y": 1, "z": 2}}, {"side": 2, "index": {"x": 0, "y": 2, "z": 2}}, {"side": 0, "index": {"x": 1, "y": 2, "z": 1}}, {"side": 0, "index": {"x": 1, "y": 2, "z": 0}}, {"side": 0, "index": {"x": 2, "y": 2, "z": 1}}]}, "score": 364, "playedAt": 0, "playerIndex": 1}, {"type": {"playedWord": [{"side": 1, "index": {"x": 1, "y": 0, "z": 2}}, {"side": 1, "index": {"x": 0, "y": 1, "z": 2}}, {"side": 2, "index": {"x": 0, "y": 2, "z": 2}}, {"side": 0, "index": {"x": 0, "y": 2, "z": 1}}, {"side": 0, "index": {"x": 0, "y": 2, "z": 0}}, {"side": 2, "index": {"x": 0, "y": 2, "z": 1}}, {"side": 1, "index": {"x": 1, "y": 2, "z": 0}}]}, "score": 336, "playedAt": 0, "playerIndex": 0}, {"type": {"playedWord": [{"side": 0, "index": {"x": 2, "y": 2, "z": 0}}, {"side": 0, "index": {"x": 1, "y": 2, "z": 0}}, {"side": 1, "index": {"x": 2, "y": 2, "z": 0}}, {"side": 0, "index": {"x": 2, "y": 1, "z": 1}}, {"side": 0, "index": {"x": 1, "y": 1, "z": 2}}, {"side": 2, "index": {"x": 0, "y": 2, "z": 1}}, {"side": 2, "index": {"x": 0, "y": 2, "z": 2}}]}, "score": 392, "playedAt": 0, "playerIndex": 1}, {"type": {"removedCube": {"x": 2, "y": 1, "z": 1}}, "score": 0, "playedAt": 0, "playerIndex": 0}, {"type": {"playedWord": [{"side": 0, "index": {"x": 1, "y": 1, "z": 1}}, {"side": 2, "index": {"x": 0, "y": 2, "z": 0}}, {"side": 0, "index": {"x": 1, "y": 1, "z": 0}}, {"side": 2, "index": {"x": 0, "y": 2, "z": 1}}, {"side": 0, "index": {"x": 0, "y": 1, "z": 2}}]}, "score": 130, "playedAt": 0, "playerIndex": 0}, {"type": {"playedWord": [{"side": 0, "index": {"x": 1, "y": 1, "z": 0}}, {"side": 2, "index": {"x": 0, "y": 2, "z": 0}}, {"side": 0, "index": {"x": 1, "y": 1, "z": 1}}, {"side": 2, "index": {"x": 1, "y": 1, "z": 1}}, {"side": 0, "index": {"x": 1, "y": 0, "z": 2}}, {"side": 1, "index": {"x": 1, "y": 1, "z": 1}}, {"side": 0, "index": {"x": 0, "y": 1, "z": 1}}, {"side": 2, "index": {"x": 0, "y": 1, "z": 2}}, {"side": 1, "index": {"x": 0, "y": 1, "z": 2}}, {"side": 1, "index": {"x": 1, "y": 0, "z": 2}}]}, "score": 1540, "playedAt": 0, "playerIndex": 1, "reactions": { "1": "😇" }}, {"type": {"removedCube": {"x": 2, "y": 2, "z": 0}}, "score": 0, "playedAt": 0, "playerIndex": 0}, {"type": {"playedWord": [{"side": 1, "index": {"x": 2, "y": 0, "z": 0}}, {"side": 2, "index": {"x": 1, "y": 1, "z": 1}}, {"side": 0, "index": {"x": 1, "y": 1, "z": 1}}, {"side": 1, "index": {"x": 1, "y": 1, "z": 1}}, {"side": 0, "index": {"x": 0, "y": 1, "z": 1}}]}, "score": 100, "playedAt": 0, "playerIndex": 0, "reactions": { "0": "😭" }}, {"type": {"removedCube": {"x": 2, "y": 1, "z": 0}}, "score": 0, "playedAt": 0, "playerIndex": 1}, {"type": {"playedWord": [{"side": 1, "index": {"x": 1, "y": 0, "z": 2}}, {"side": 0, "index": {"x": 0, "y": 0, "z": 2}}, {"side": 0, "index": {"x": 1, "y": 0, "z": 1}}, {"side": 1, "index": {"x": 0, "y": 1, "z": 1}}, {"side": 2, "index": {"x": 0, "y": 1, "z": 1}}]}, "score": 110, "playedAt": 0, "playerIndex": 1}, {"type": {"removedCube": {"x": 0, "y": 0, "z": 2}}, "score": 0, "playedAt": 0, "playerIndex": 0}, {"type": {"playedWord": [{"side": 0, "index": {"x": 2, "y": 0, "z": 2}}, {"side": 1, "index": {"x": 1, "y": 0, "z": 1}}, {"side": 0, "index": {"x": 1, "y": 0, "z": 1}}, {"side": 1, "index": {"x": 0, "y": 1, "z": 1}}, {"side": 2, "index": {"x": 0, "y": 1, "z": 1}}]}, "score": 110, "playedAt": 0, "playerIndex": 0}, {"type": {"playedWord": [{"side": 0, "index": {"x": 1, "y": 1, "z": 0}}, {"side": 2, "index": {"x": 0, "y": 2, "z": 0}}, {"side": 2, "index": {"x": 0, "y": 1, "z": 1}}, {"side": 0, "index": {"x": 1, "y": 0, "z": 1}}, {"side": 1, "index": {"x": 0, "y": 0, "z": 1}}]}, "score": 100, "playedAt": 0, "playerIndex": 1}, {"type": {"playedWord": [{"side": 2, "index": {"x": 2, "y": 0, "z": 0}}, {"side": 0, "index": {"x": 2, "y": 0, "z": 0}}, {"side": 0, "index": {"x": 1, "y": 0, "z": 0}}]}, "score": 68, "playedAt": 0, "playerIndex": 0}, {"type": {"playedWord": [{"side": 2, "index": {"x": 2, "y": 0, "z": 0}}, {"side": 0, "index": {"x": 2, "y": 0, "z": 0}}]}, "score": 42, "playedAt": 0, "playerIndex": 1}, {"type": {"playedWord": [{"side": 2, "index": {"x": 0, "y": 1, "z": 0}}, {"side": 0, "index": {"x": 0, "y": 0, "z": 1}}, {"side": 1, "index": {"x": 0, "y": 0, "z": 1}}, {"side": 2, "index": {"x": 0, "y": 0, "z": 1}}]}, "score": 44, "playedAt": 0, "playerIndex": 0}, {"type": {"removedCube": {"x": 2, "y": 0, "z": 2}}, "score": 0, "playedAt": 0, "playerIndex": 1}, {"type": {"removedCube": {"x": 2, "y": 0, "z": 0}}, "score": 0, "playedAt": 0, "playerIndex": 1}, {"type": {"playedWord": [{"side": 1, "index": {"x": 0, "y": 0, "z": 1}}, {"side": 2, "index": {"x": 0, "y": 0, "z": 1}}, {"side": 0, "index": {"x": 0, "y": 0, "z": 1}}]}, "score": 21, "playedAt": 0, "playerIndex": 0}],"playerId":"00000000-0000-0000-0000-000000000000","moveIndex":10,"playerDisplayName":""}
    """#.utf8
  )
)
