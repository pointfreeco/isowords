import ActiveGamesFeature
import ComposableArchitecture
import CubeCore
import GameFeature
import Overture
import SharedModels
import SharedSwiftUIEnvironment
import SwiftUI

var turnBasedAppStoreView: AnyView {
  let json = """
    {"puzzle":[[[{"top": {"side": 0, "letter": "N"}, "left": {"side": 1, "letter": "M"}, "right": {"side": 2, "letter": "B"}}, {"top": {"side": 0, "letter": "O"}, "left": {"side": 1, "letter": "S"}, "right": {"side": 2, "letter": "H"}}, {"top": {"side": 0, "letter": "H"}, "left": {"side": 1, "letter": "M"}, "right": {"side": 2, "letter": "N"}}], [{"top": {"side": 0, "letter": "D"}, "left": {"side": 1, "letter": "N"}, "right": {"side": 2, "letter": "M"}}, {"top": {"side": 0, "letter": "R"}, "left": {"side": 1, "letter": "N"}, "right": {"side": 2, "letter": "T"}}, {"top": {"side": 0, "letter": "N"}, "left": {"side": 1, "letter": "U"}, "right": {"side": 2, "letter": "O"}}], [{"top": {"side": 0, "letter": "I"}, "left": {"side": 1, "letter": "P"}, "right": {"side": 2, "letter": "O"}}, {"top": {"side": 0, "letter": "F"}, "left": {"side": 1, "letter": "E"}, "right": {"side": 2, "letter": "E"}}, {"top": {"side": 0, "letter": "U"}, "left": {"side": 1, "letter": "T"}, "right": {"side": 2, "letter": "R"}}]], [[{"top": {"side": 0, "letter": "D"}, "left": {"side": 1, "letter": "H"}, "right": {"side": 2, "letter": "E"}}, {"top": {"side": 0, "letter": "E"}, "left": {"side": 1, "letter": "L"}, "right": {"side": 2, "letter": "I"}}, {"top": {"side": 0, "letter": "F"}, "left": {"side": 1, "letter": "S"}, "right": {"side": 2, "letter": "N"}}], [{"top": {"side": 0, "letter": "V"}, "left": {"side": 1, "letter": "H"}, "right": {"side": 2, "letter": "P"}}, {"top": {"side": 0, "letter": "C"}, "left": {"side": 1, "letter": "E"}, "right": {"side": 2, "letter": "I"}}, {"top": {"side": 0, "letter": "R"}, "left": {"side": 1, "letter": "N"}, "right": {"side": 2, "letter": "M"}}], [{"top": {"side": 0, "letter": "E"}, "left": {"side": 1, "letter": "S"}, "right": {"side": 2, "letter": "A"}}, {"top": {"side": 0, "letter": "I"}, "left": {"side": 1, "letter": "T"}, "right": {"side": 2, "letter": "O"}}, {"top": {"side": 0, "letter": "P"}, "left": {"side": 1, "letter": "R"}, "right": {"side": 2, "letter": "Y"}}]], [[{"top": {"side": 0, "letter": "A"}, "left": {"side": 1, "letter": "N"}, "right": {"side": 2, "letter": "QU"}}, {"top": {"side": 0, "letter": "E"}, "left": {"side": 1, "letter": "V"}, "right": {"side": 2, "letter": "L"}}, {"top": {"side": 0, "letter": "B"}, "left": {"side": 1, "letter": "U"}, "right": {"side": 2, "letter": "U"}}], [{"top": {"side": 0, "letter": "N"}, "left": {"side": 1, "letter": "J"}, "right": {"side": 2, "letter": "O"}}, {"top": {"side": 0, "letter": "E"}, "left": {"side": 1, "letter": "A"}, "right": {"side": 2, "letter": "F"}}, {"top": {"side": 0, "letter": "E"}, "left": {"side": 1, "letter": "M"}, "right": {"side": 2, "letter": "T"}}], [{"top": {"side": 0, "letter": "V"}, "left": {"side": 1, "letter": "N"}, "right": {"side": 2, "letter": "B"}}, {"top": {"side": 0, "letter": "S"}, "left": {"side": 1, "letter": "W"}, "right": {"side": 2, "letter": "H"}}, {"top": {"side": 0, "letter": "G"}, "left": {"side": 1, "letter": "M"}, "right": {"side": 2, "letter": "L"}}]]],"moves":[{"type": {"removedCube": {"x": 2, "y": 2, "z": 2}}, "score": 0, "playedAt": 0, "playerIndex": 0}, {"type": {"playedWord": [{"side": 1, "index": {"x": 2, "y": 2, "z": 1}}, {"side": 0, "index": {"x": 1, "y": 2, "z": 1}}, {"side": 0, "index": {"x": 2, "y": 2, "z": 0}}, {"side": 0, "index": {"x": 1, "y": 2, "z": 0}}, {"side": 0, "index": {"x": 2, "y": 2, "z": 1}}]}, "score": 130, "playedAt": 0, "playerIndex": 0}, {"type": {"playedWord": [{"side": 2, "index": {"x": 2, "y": 2, "z": 0}}, {"side": 2, "index": {"x": 2, "y": 1, "z": 0}}, {"side": 2, "index": {"x": 2, "y": 0, "z": 1}}, {"side": 2, "index": {"x": 2, "y": 1, "z": 2}}, {"side": 0, "index": {"x": 2, "y": 1, "z": 2}}, {"side": 1, "index": {"x": 1, "y": 2, "z": 2}}]}, "score": 216, "playedAt": 0, "playerIndex": 1}, {"type": {"playedWord": [{"side": 1, "index": {"x": 2, "y": 2, "z": 1}}, {"side": 0, "index": {"x": 1, "y": 2, "z": 1}}, {"side": 0, "index": {"x": 2, "y": 2, "z": 1}}, {"side": 2, "index": {"x": 2, "y": 2, "z": 1}}, {"side": 2, "index": {"x": 2, "y": 1, "z": 1}}, {"side": 2, "index": {"x": 2, "y": 0, "z": 2}}, {"side": 2, "index": {"x": 2, "y": 0, "z": 1}}]}, "score": 560, "playedAt": 0, "playerIndex": 0}, {"type": {"playedWord": [{"side": 2, "index": {"x": 2, "y": 1, "z": 1}}, {"side": 2, "index": {"x": 2, "y": 0, "z": 1}}, {"side": 2, "index": {"x": 2, "y": 0, "z": 2}}, {"side": 2, "index": {"x": 2, "y": 1, "z": 2}}, {"side": 0, "index": {"x": 2, "y": 1, "z": 2}}, {"side": 2, "index": {"x": 1, "y": 2, "z": 2}}]}, "score": 288, "playedAt": 0, "playerIndex": 1}, {"type": {"removedCube": {"x": 1, "y": 2, "z": 2}}, "score": 0, "playedAt": 0, "playerIndex": 0}, {"type": {"playedWord": [{"side": 0, "index": {"x": 0, "y": 2, "z": 1}}, {"side": 0, "index": {"x": 0, "y": 2, "z": 2}}, {"side": 1, "index": {"x": 0, "y": 2, "z": 2}}, {"side": 1, "index": {"x": 0, "y": 1, "z": 2}}, {"side": 0, "index": {"x": 1, "y": 1, "z": 2}}, {"side": 0, "index": {"x": 2, "y": 1, "z": 2}}]}, "score": 216, "playedAt": 0, "playerIndex": 0}, {"type": {"playedWord": [{"side": 2, "index": {"x": 2, "y": 2, "z": 1}}, {"side": 1, "index": {"x": 2, "y": 1, "z": 1}}, {"side": 0, "index": {"x": 1, "y": 1, "z": 2}}, {"side": 2, "index": {"x": 0, "y": 2, "z": 2}}, {"side": 0, "index": {"x": 1, "y": 2, "z": 1}}, {"side": 0, "index": {"x": 1, "y": 2, "z": 0}}, {"side": 0, "index": {"x": 2, "y": 2, "z": 1}}]}, "score": 364, "playedAt": 0, "playerIndex": 1}, {"type": {"playedWord": [{"side": 1, "index": {"x": 1, "y": 0, "z": 2}}, {"side": 1, "index": {"x": 0, "y": 1, "z": 2}}, {"side": 2, "index": {"x": 0, "y": 2, "z": 2}}, {"side": 0, "index": {"x": 0, "y": 2, "z": 1}}, {"side": 0, "index": {"x": 0, "y": 2, "z": 0}}, {"side": 2, "index": {"x": 0, "y": 2, "z": 1}}, {"side": 1, "index": {"x": 1, "y": 2, "z": 0}}]}, "score": 336, "playedAt": 0, "playerIndex": 0}, {"type": {"playedWord": [{"side": 0, "index": {"x": 2, "y": 2, "z": 0}}, {"side": 0, "index": {"x": 1, "y": 2, "z": 0}}, {"side": 1, "index": {"x": 2, "y": 2, "z": 0}}, {"side": 0, "index": {"x": 2, "y": 1, "z": 1}}, {"side": 0, "index": {"x": 1, "y": 1, "z": 2}}, {"side": 2, "index": {"x": 0, "y": 2, "z": 1}}, {"side": 2, "index": {"x": 0, "y": 2, "z": 2}}]}, "score": 392, "playedAt": 0, "playerIndex": 1}, {"type": {"removedCube": {"x": 2, "y": 1, "z": 1}}, "score": 0, "playedAt": 0, "playerIndex": 0}, {"type": {"playedWord": [{"side": 0, "index": {"x": 1, "y": 1, "z": 1}}, {"side": 2, "index": {"x": 0, "y": 2, "z": 0}}, {"side": 0, "index": {"x": 1, "y": 1, "z": 0}}, {"side": 2, "index": {"x": 0, "y": 2, "z": 1}}, {"side": 0, "index": {"x": 0, "y": 1, "z": 2}}]}, "score": 130, "playedAt": 0, "playerIndex": 0}, {"type": {"playedWord": [{"side": 0, "index": {"x": 1, "y": 1, "z": 0}}, {"side": 2, "index": {"x": 0, "y": 2, "z": 0}}, {"side": 0, "index": {"x": 1, "y": 1, "z": 1}}, {"side": 2, "index": {"x": 1, "y": 1, "z": 1}}, {"side": 0, "index": {"x": 1, "y": 0, "z": 2}}, {"side": 1, "index": {"x": 1, "y": 1, "z": 1}}, {"side": 0, "index": {"x": 0, "y": 1, "z": 1}}, {"side": 2, "index": {"x": 0, "y": 1, "z": 2}}, {"side": 1, "index": {"x": 0, "y": 1, "z": 2}}, {"side": 1, "index": {"x": 1, "y": 0, "z": 2}}]}, "score": 1540, "playedAt": 0, "playerIndex": 1, "reactions": { "1": "😇" }}, {"type": {"removedCube": {"x": 2, "y": 2, "z": 0}}, "score": 0, "playedAt": 0, "playerIndex": 0}, {"type": {"playedWord": [{"side": 1, "index": {"x": 2, "y": 0, "z": 0}}, {"side": 2, "index": {"x": 1, "y": 1, "z": 1}}, {"side": 0, "index": {"x": 1, "y": 1, "z": 1}}, {"side": 1, "index": {"x": 1, "y": 1, "z": 1}}, {"side": 0, "index": {"x": 0, "y": 1, "z": 1}}]}, "score": 100, "playedAt": 0, "playerIndex": 0, "reactions": { "0": "😭" }}, {"type": {"removedCube": {"x": 2, "y": 1, "z": 0}}, "score": 0, "playedAt": 0, "playerIndex": 1}, {"type": {"playedWord": [{"side": 1, "index": {"x": 1, "y": 0, "z": 2}}, {"side": 0, "index": {"x": 0, "y": 0, "z": 2}}, {"side": 0, "index": {"x": 1, "y": 0, "z": 1}}, {"side": 1, "index": {"x": 0, "y": 1, "z": 1}}, {"side": 2, "index": {"x": 0, "y": 1, "z": 1}}]}, "score": 110, "playedAt": 0, "playerIndex": 1}, {"type": {"removedCube": {"x": 0, "y": 0, "z": 2}}, "score": 0, "playedAt": 0, "playerIndex": 0}, {"type": {"playedWord": [{"side": 0, "index": {"x": 2, "y": 0, "z": 2}}, {"side": 1, "index": {"x": 1, "y": 0, "z": 1}}, {"side": 0, "index": {"x": 1, "y": 0, "z": 1}}, {"side": 1, "index": {"x": 0, "y": 1, "z": 1}}, {"side": 2, "index": {"x": 0, "y": 1, "z": 1}}]}, "score": 110, "playedAt": 0, "playerIndex": 0}, {"type": {"playedWord": [{"side": 0, "index": {"x": 1, "y": 1, "z": 0}}, {"side": 2, "index": {"x": 0, "y": 2, "z": 0}}, {"side": 2, "index": {"x": 0, "y": 1, "z": 1}}, {"side": 0, "index": {"x": 1, "y": 0, "z": 1}}, {"side": 1, "index": {"x": 0, "y": 0, "z": 1}}]}, "score": 100, "playedAt": 0, "playerIndex": 1}, {"type": {"playedWord": [{"side": 2, "index": {"x": 2, "y": 0, "z": 0}}, {"side": 0, "index": {"x": 2, "y": 0, "z": 0}}, {"side": 0, "index": {"x": 1, "y": 0, "z": 0}}]}, "score": 68, "playedAt": 0, "playerIndex": 0}, {"type": {"playedWord": [{"side": 2, "index": {"x": 2, "y": 0, "z": 0}}, {"side": 0, "index": {"x": 2, "y": 0, "z": 0}}]}, "score": 42, "playedAt": 0, "playerIndex": 1}, {"type": {"playedWord": [{"side": 2, "index": {"x": 0, "y": 1, "z": 0}}, {"side": 0, "index": {"x": 0, "y": 0, "z": 1}}, {"side": 1, "index": {"x": 0, "y": 0, "z": 1}}, {"side": 2, "index": {"x": 0, "y": 0, "z": 1}}]}, "score": 44, "playedAt": 0, "playerIndex": 0}, {"type": {"removedCube": {"x": 2, "y": 0, "z": 2}}, "score": 0, "playedAt": 0, "playerIndex": 1}, {"type": {"removedCube": {"x": 2, "y": 0, "z": 0}}, "score": 0, "playedAt": 0, "playerIndex": 1}, {"type": {"playedWord": [{"side": 1, "index": {"x": 0, "y": 0, "z": 1}}, {"side": 2, "index": {"x": 0, "y": 0, "z": 1}}, {"side": 0, "index": {"x": 0, "y": 0, "z": 1}}]}, "score": 21, "playedAt": 0, "playerIndex": 0}],"playerId":"00000000-0000-0000-0000-000000000000","moveIndex":10,"playerDisplayName":""}
    """
  let vocab = try! JSONDecoder().decode(FetchVocabWordResponse.self, from: Data(json.utf8))
  let moves = Moves(vocab.moves.prefix(upTo: 15))

  let state = GameFeatureState(
    game: GameState(
      activeGames: ActiveGamesState(),
      bottomMenu: nil,
      cubes: Puzzle(archivableCubes: vocab.puzzle, moves: moves),
      cubeStartedShakingAt: nil,
      gameContext: .turnBased(
        .init(
          localPlayer: update(.authenticated) {
            $0.displayName = "stephen"
          },
          match: update(.inProgress) {
            $0.participants[1].player?.displayName = "mbrandonw"
          },
          metadata: .init(playerIndexToId: [:], updatedAt: nil)
        )
      ),
      gameCurrentTime: Date(),
      gameMode: .unlimited,
      gameOver: nil,
      gameStartTime: Date(),
      isDemo: false,
      isGameLoaded: true,
      isPanning: false,
      isOnLowPowerMode: false,
      isSettingsPresented: false,
      isTrayVisible: false,
      language: .en,
      moves: moves,
      optimisticallySelectedFace: nil,
      secondsPlayed: 60 * 30,
      selectedWord: (/Move.MoveType.playedWord).extract(from: vocab.moves[vocab.moveIndex].type)
        ?? [],
      selectedWordIsValid: true,
      upgradeInterstitial: nil,
      wordSubmit: WordSubmitButtonState()
    ),
    settings: .init()
  )
  let store = Store<GameFeatureState, GameFeatureAction>(
    initialState: state,
    reducer: .empty,
    environment: ()
  )
  let view = GameFeatureView(
    content: CubeView(
      store: Store<CubeSceneView.ViewState, CubeSceneView.ViewAction>(
        initialState: CubeSceneView.ViewState(
          game: state.game!,
          nub: nil,
          settings: .init()
        ),
        reducer: .empty,
        environment: ()
      )
    ),
    store: store
  )
  .environment(\.yourImage, UIImage(named: "you", in: .module, with: nil))
  .environment(\.opponentImage, UIImage(named: "opponent", in: .module, with: nil))
  return AnyView(view)
}
