import ActiveGamesFeature
import Bloom
import ComposableArchitecture
import CubeCore
import GameFeature
import Gen
import Overture
import SharedModels
import Styleguide
import SwiftUI

var gameplayAppStoreView: AnyView {
  // FIXME: Shouldn't have to recreate this logic...
  let word = "EXCHANGES"
  let colors =
    Styleguide.letterColors.first { key, _ in
      key.contains(word)
    }?
    .value ?? []
  let vertexGenerator: AnyIterator<CGPoint> = {
    var rng = Xoshiro(seed: 0)
    var vertices: [CGPoint] = [
      .init(x: 0.04, y: 0.04),
      .init(x: 0.04, y: -0.04),
      .init(x: -0.04, y: -0.04),
      .init(x: -0.04, y: 0.04),
    ]
    var index = 0
    return AnyIterator {
      defer { index += 1 }
      if index % vertices.count == 0 {
        vertices.shuffle(using: &rng)
      }
      return vertices[index % vertices.count]
    }
  }()
  let blooms: [Bloom] = (0..<word.count).reduce(into: []) { blooms, index in
    var vertex = vertexGenerator.next()!
    let width: CGFloat = 500 * 1.2
    let height: CGFloat = 750 * 0.85
    vertex.x *= CGFloat(index) * width
    vertex.y *= CGFloat(index) * height
    let size = (1 + CGFloat(index) * 0.1) * width
    blooms.append(
      Bloom(
        color: colors[index % colors.count].withAlphaComponent(0.5),
        index: index,
        size: size,
        offset: vertex
      )
    )
  }

  let json = #"""
    {"puzzle":[[[{"right":{"letter":"S","side":2},"left":{"letter":"T","side":1},"top":{"letter":"I","side":0}},{"left":{"side":1,"letter":"B"},"right":{"side":2,"letter":"T"},"top":{"side":0,"letter":"H"}},{"right":{"side":2,"letter":"E"},"left":{"letter":"K","side":1},"top":{"side":0,"letter":"O"}}],[{"right":{"side":2,"letter":"A"},"left":{"side":1,"letter":"P"},"top":{"side":0,"letter":"Y"}},{"right":{"side":2,"letter":"D"},"top":{"side":0,"letter":"S"},"left":{"letter":"T","side":1}},{"right":{"letter":"L","side":2},"top":{"side":0,"letter":"S"},"left":{"letter":"D","side":1}}],[{"right":{"side":2,"letter":"E"},"left":{"side":1,"letter":"N"},"top":{"side":0,"letter":"T"}},{"right":{"letter":"H","side":2},"left":{"letter":"M","side":1},"top":{"side":0,"letter":"A"}},{"top":{"side":0,"letter":"R"},"right":{"side":2,"letter":"O"},"left":{"letter":"I","side":1}}]],[[{"right":{"side":2,"letter":"A"},"top":{"side":0,"letter":"T"},"left":{"letter":"E","side":1}},{"left":{"letter":"N","side":1},"right":{"letter":"O","side":2},"top":{"letter":"V","side":0}},{"left":{"side":1,"letter":"S"},"right":{"side":2,"letter":"C"},"top":{"letter":"Y","side":0}}],[{"left":{"letter":"R","side":1},"right":{"side":2,"letter":"I"},"top":{"side":0,"letter":"G"}},{"right":{"side":2,"letter":"H"},"top":{"side":0,"letter":"R"},"left":{"side":1,"letter":"E"}},{"right":{"side":2,"letter":"R"},"top":{"letter":"F","side":0},"left":{"letter":"S","side":1}}],[{"right":{"side":2,"letter":"L"},"left":{"side":1,"letter":"C"},"top":{"letter":"O","side":0}},{"right":{"letter":"C","side":2},"top":{"side":0,"letter":"X"},"left":{"side":1,"letter":"S"}},{"left":{"side":1,"letter":"N"},"right":{"letter":"H","side":2},"top":{"letter":"N","side":0}}]],[[{"right":{"letter":"C","side":2},"top":{"letter":"I","side":0},"left":{"letter":"R","side":1}},{"top":{"side":0,"letter":"G"},"right":{"letter":"B","side":2},"left":{"side":1,"letter":"I"}},{"right":{"letter":"P","side":2},"left":{"letter":"D","side":1},"top":{"side":0,"letter":"G"}}],[{"left":{"letter":"R","side":1},"right":{"side":2,"letter":"I"},"top":{"side":0,"letter":"QU"}},{"left":{"letter":"N","side":1},"right":{"side":2,"letter":"D"},"top":{"letter":"A","side":0}},{"right":{"letter":"A","side":2},"top":{"side":0,"letter":"T"},"left":{"letter":"Y","side":1}}],[{"top":{"letter":"E","side":0},"right":{"letter":"Y","side":2},"left":{"letter":"I","side":1}},{"top":{"side":0,"letter":"R"},"right":{"side":2,"letter":"E"},"left":{"letter":"M","side":1}},{"right":{"letter":"A","side":2},"left":{"letter":"V","side":1},"top":{"letter":"M","side":0}}]]],"moves":[{"score":420,"playedAt":0,"type":{"playedWord":[{"side":1,"index":{"z":2,"x":0,"y":2}},{"side":1,"index":{"z":2,"x":1,"y":2}},{"side":1,"index":{"z":2,"x":2,"y":2}},{"side":2,"index":{"z":2,"x":2,"y":2}},{"side":2,"index":{"z":1,"x":2,"y":1}},{"side":2,"index":{"z":1,"x":2,"y":2}},{"side":0,"index":{"z":1,"x":2,"y":2}}]}},{"score":288,"type":{"playedWord":[{"side":2,"index":{"z":0,"x":2,"y":0}},{"side":2,"index":{"z":0,"x":2,"y":1}},{"side":2,"index":{"z":1,"x":2,"y":1}},{"side":2,"index":{"z":1,"x":2,"y":2}},{"side":0,"index":{"z":1,"x":2,"y":2}},{"side":2,"index":{"z":0,"x":2,"y":2}}]},"playedAt":0},{"score":120,"type":{"playedWord":[{"side":1,"index":{"z":2,"x":0,"y":1}},{"side":1,"index":{"z":2,"x":0,"y":2}},{"side":1,"index":{"z":2,"x":1,"y":1}},{"side":1,"index":{"z":2,"x":0,"y":0}},{"side":1,"index":{"z":2,"x":1,"y":0}}]},"playedAt":0},{"score":110,"type":{"playedWord":[{"side":0,"index":{"z":2,"x":0,"y":2}},{"side":1,"index":{"z":2,"x":0,"y":2}},{"side":1,"index":{"z":2,"x":1,"y":1}},{"side":1,"index":{"z":2,"x":0,"y":0}},{"side":1,"index":{"z":2,"x":1,"y":0}}]},"playedAt":0},{"score":160,"playedAt":0,"type":{"playedWord":[{"side":0,"index":{"z":0,"x":2,"y":2}},{"side":0,"index":{"z":1,"x":1,"y":2}},{"side":0,"index":{"z":1,"x":0,"y":2}},{"side":1,"index":{"z":1,"x":0,"y":2}},{"side":0,"index":{"z":2,"x":0,"y":1}}]}},{"score":0,"type":{"removedCube":{"y":2,"z":2,"x":2}},"playedAt":0},{"score":120,"playedAt":0,"type":{"playedWord":[{"side":0,"index":{"z":1,"x":2,"y":2}},{"side":2,"index":{"z":1,"x":2,"y":2}},{"side":2,"index":{"z":2,"x":2,"y":1}},{"side":1,"index":{"z":2,"x":2,"y":0}},{"side":1,"index":{"z":2,"x":2,"y":1}}]}},{"score":378,"type":{"playedWord":[{"side":2,"index":{"z":2,"x":2,"y":0}},{"side":2,"index":{"z":2,"x":2,"y":1}},{"side":0,"index":{"z":2,"x":2,"y":1}},{"side":2,"index":{"z":1,"x":1,"y":2}},{"side":2,"index":{"z":2,"x":1,"y":2}},{"side":1,"index":{"z":2,"x":2,"y":1}}]},"playedAt":0},{"score":160,"type":{"playedWord":[{"side":2,"index":{"z":1,"x":2,"y":0}},{"side":2,"index":{"z":2,"x":2,"y":1}},{"side":0,"index":{"z":2,"x":2,"y":1}},{"side":2,"index":{"z":1,"x":1,"y":2}},{"side":2,"index":{"z":2,"x":1,"y":2}}]},"playedAt":0},{"score":0,"type":{"removedCube":{"y":1,"z":2,"x":1}},"playedAt":0},{"score":1458,"type":{"playedWord":[{"side":0,"index":{"z":0,"x":2,"y":2}},{"side":0,"index":{"z":1,"x":1,"y":2}},{"side":2,"index":{"z":1,"x":1,"y":2}},{"side":2,"index":{"z":2,"x":1,"y":2}},{"side":0,"index":{"z":1,"x":2,"y":1}},{"side":1,"index":{"z":1,"x":2,"y":1}},{"side":0,"index":{"z":2,"x":2,"y":0}},{"side":1,"index":{"z":1,"x":1,"y":1}},{"side":0,"index":{"z":2,"x":0,"y":1}}]},"playedAt":0},{"score":0,"playedAt":0,"type":{"removedCube":{"y":2,"z":0,"x":2}}},{"score":504,"playedAt":0,"type":{"playedWord":[{"side":1,"index":{"z":1,"x":0,"y":2}},{"side":0,"index":{"z":1,"x":0,"y":2}},{"side":0,"index":{"z":0,"x":0,"y":2}},{"side":1,"index":{"z":0,"x":1,"y":2}},{"side":2,"index":{"z":1,"x":0,"y":2}},{"side":1,"index":{"z":1,"x":1,"y":1}},{"side":0,"index":{"z":2,"x":0,"y":1}}]}},{"score":532,"playedAt":0,"type":{"playedWord":[{"side":1,"index":{"z":1,"x":0,"y":2}},{"side":0,"index":{"z":1,"x":0,"y":2}},{"side":0,"index":{"z":0,"x":0,"y":2}},{"side":1,"index":{"z":0,"x":1,"y":2}},{"side":2,"index":{"z":1,"x":0,"y":2}},{"side":1,"index":{"z":1,"x":1,"y":1}},{"side":0,"index":{"z":1,"x":1,"y":1}}]}},{"score":170,"playedAt":0,"type":{"playedWord":[{"side":1,"index":{"z":0,"x":1,"y":2}},{"side":0,"index":{"z":1,"x":2,"y":1}},{"side":1,"index":{"z":0,"x":1,"y":1}},{"side":0,"index":{"z":1,"x":1,"y":0}},{"side":0,"index":{"z":2,"x":1,"y":0}}]}},{"score":130,"playedAt":0,"type":{"playedWord":[{"side":1,"index":{"z":0,"x":1,"y":1}},{"side":0,"index":{"z":1,"x":2,"y":1}},{"side":1,"index":{"z":1,"x":2,"y":1}},{"side":0,"index":{"z":2,"x":2,"y":0}},{"side":0,"index":{"z":2,"x":1,"y":0}}]}},{"score":234,"type":{"playedWord":[{"side":2,"index":{"z":1,"x":2,"y":0}},{"side":2,"index":{"z":0,"x":2,"y":1}},{"side":1,"index":{"z":0,"x":2,"y":1}},{"side":1,"index":{"z":0,"x":1,"y":1}},{"side":2,"index":{"z":0,"x":0,"y":2}},{"side":2,"index":{"z":1,"x":0,"y":1}}]},"playedAt":0},{"score":180,"type":{"playedWord":[{"side":0,"index":{"z":0,"x":2,"y":1}},{"side":2,"index":{"z":0,"x":2,"y":1}},{"side":1,"index":{"z":0,"x":2,"y":1}},{"side":0,"index":{"z":0,"x":1,"y":0}}]},"playedAt":0},{"score":160,"type":{"playedWord":[{"side":2,"index":{"z":1,"x":2,"y":0}},{"side":0,"index":{"z":0,"x":2,"y":0}},{"side":0,"index":{"z":1,"x":2,"y":0}},{"side":0,"index":{"z":2,"x":2,"y":0}},{"side":0,"index":{"z":2,"x":1,"y":0}}]},"playedAt":0},{"score":130,"playedAt":0,"type":{"playedWord":[{"side":1,"index":{"z":2,"x":0,"y":0}},{"side":2,"index":{"z":2,"x":0,"y":0}},{"side":1,"index":{"z":1,"x":1,"y":0}},{"side":2,"index":{"z":1,"x":0,"y":1}},{"side":0,"index":{"z":2,"x":0,"y":0}}]}},{"score":90,"type":{"playedWord":[{"side":0,"index":{"z":0,"x":0,"y":2}},{"side":2,"index":{"z":0,"x":0,"y":2}},{"side":1,"index":{"z":0,"x":0,"y":2}},{"side":2,"index":{"z":1,"x":0,"y":1}},{"side":0,"index":{"z":1,"x":0,"y":1}}]},"playedAt":0},{"score":30,"playedAt":0,"type":{"playedWord":[{"side":1,"index":{"z":0,"x":0,"y":1}},{"side":2,"index":{"z":0,"x":0,"y":1}},{"side":0,"index":{"z":0,"x":0,"y":1}}]}},{"score":30,"playedAt":0,"type":{"playedWord":[{"side":0,"index":{"z":0,"x":0,"y":1}},{"side":2,"index":{"z":0,"x":0,"y":1}},{"side":1,"index":{"z":0,"x":0,"y":1}}]}},{"score":48,"type":{"playedWord":[{"side":1,"index":{"z":0,"x":0,"y":1}},{"side":2,"index":{"z":0,"x":0,"y":1}},{"side":0,"index":{"z":0,"x":1,"y":0}},{"side":0,"index":{"z":1,"x":0,"y":0}}]},"playedAt":0},{"score":100,"playedAt":0,"type":{"playedWord":[{"side":0,"index":{"z":0,"x":1,"y":0}},{"side":2,"index":{"z":1,"x":1,"y":0}},{"side":1,"index":{"z":0,"x":2,"y":0}},{"side":0,"index":{"z":0,"x":2,"y":0}},{"side":2,"index":{"z":0,"x":2,"y":0}}]}},{"score":36,"type":{"playedWord":[{"side":2,"index":{"z":0,"x":2,"y":0}},{"side":1,"index":{"z":0,"x":2,"y":0}},{"side":2,"index":{"z":1,"x":1,"y":0}},{"side":1,"index":{"z":1,"x":1,"y":0}}]},"playedAt":0},{"score":48,"type":{"playedWord":[{"side":2,"index":{"z":0,"x":0,"y":0}},{"side":0,"index":{"z":1,"x":0,"y":0}},{"side":0,"index":{"z":0,"x":0,"y":0}},{"side":0,"index":{"z":1,"x":1,"y":0}}]},"playedAt":0},{"score":21,"type":{"playedWord":[{"side":0,"index":{"z":1,"x":1,"y":0}},{"side":0,"index":{"z":0,"x":0,"y":0}},{"side":2,"index":{"z":0,"x":0,"y":0}}]},"playedAt":0},{"score":36,"type":{"playedWord":[{"side":2,"index":{"z":0,"x":0,"y":0}},{"side":0,"index":{"z":1,"x":0,"y":0}},{"side":0,"index":{"z":0,"x":0,"y":0}},{"side":2,"index":{"z":1,"x":0,"y":0}}]},"playedAt":0}],"playerId":"00000000-0000-0000-0000-000000000000","moveIndex":10,"playerDisplayName":""}
    """#
  let vocab = try! JSONDecoder().decode(FetchVocabWordResponse.self, from: Data(json.utf8))
  let moves = Moves(vocab.moves.prefix(upTo: vocab.moveIndex))

  let state = GameFeature.State(
    game: Game.State(
      activeGames: ActiveGamesState(),
      bottomMenu: nil,
      cubes: Puzzle(archivableCubes: vocab.puzzle, moves: moves),
      cubeStartedShakingAt: nil,
      gameContext: .dailyChallenge(.init(rawValue: .dailyChallengeId)),
      gameCurrentTime: Date(),
      gameMode: .unlimited,
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
      wordSubmit: WordSubmitButtonFeature.ButtonState()
    ),
    settings: .init()
  )
  let store = StoreOf<GameFeature>(
    initialState: state,
    reducer: EmptyReducer()
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
    )
    .background(
      Blooms(blooms: blooms).ignoresSafeArea()
    ),
    store: store
  )
  return AnyView(view)
}
