import ComposableArchitecture
import CubeCore
import FeedbackGeneratorClient
import SharedModels
import Styleguide
import SwiftUI

public struct CubePreviewState: Equatable {
  var cubes: Puzzle
  var isOnLowPowerMode: Bool
  var moves: Moves
  var nub: CubeSceneView.ViewState.NubState
  var moveIndex: Int
  var selectedCubeFaces: [IndexedCubeFace]
  let settings: CubeSceneView.ViewState.Settings

  public init(
    cubes: ArchivablePuzzle,
    isOnLowPowerMode: Bool,
    moves: Moves,
    nub: CubeSceneView.ViewState.NubState = .init(),
    moveIndex: Int,
    selectedCubeFaces: [IndexedCubeFace] = [],
    settings: CubeSceneView.ViewState.Settings
  ) {
    self.cubes = .init(archivableCubes: cubes)
    apply(moves: moves[0..<moveIndex], to: &self.cubes)

    self.isOnLowPowerMode = isOnLowPowerMode
    self.moves = moves
    self.nub = nub
    self.moveIndex = moveIndex
    self.selectedCubeFaces = selectedCubeFaces
    self.settings = settings
  }
}

public enum CubePreviewAction: Equatable {
  case cubeScene(CubeSceneView.ViewAction)
  case binding(BindingAction<CubePreviewState>)
  case onAppear
}

public struct CubePreviewEnvironment {
  var feedbackGenerator: FeedbackGeneratorClient
  var mainQueue: AnySchedulerOf<DispatchQueue>

  public init(
    feedbackGenerator: FeedbackGeneratorClient,
    mainQueue: AnySchedulerOf<DispatchQueue>
  ) {
    self.feedbackGenerator = feedbackGenerator
    self.mainQueue = mainQueue
  }
}

public let cubePreviewReducer = Reducer<
CubePreviewState,
  CubePreviewAction,
  CubePreviewEnvironment
> { state, action, environment in
  switch action {
  case .cubeScene:
    return .none

  case .binding:
    return .none

  case .onAppear:
    var effects: [Effect<CubePreviewAction, Never>] = [
      Effect.none
        .delay(for: 1, scheduler: environment.mainQueue)
        .eraseToEffect()
    ]

    var accumulatedSelectedFaces: [IndexedCubeFace] = []

    let move = state.moves[state.moveIndex]
    switch move.type {
    case let .playedWord(faces):
      for (faceIndex, face) in faces.enumerated() {
        effects.append(
          Effect(value: CubePreviewAction.binding(.set(\.nub.location, .face(face))))
            .receive(
              on: environment.mainQueue
                .animate(withDuration: 0.7, options: .curveEaseInOut)
            )
            .eraseToEffect()
        )

        accumulatedSelectedFaces.append(face)

        effects.append(
          Effect.merge(
            // Press the nub on the first character
            faceIndex == 0 ? Effect(value: .binding(.set(\.nub.isPressed, true))) : .none,
            // Tap on each face in the word being played
            Effect<CubePreviewAction, Never>.init(
              value: .binding(.set(\.selectedCubeFaces, accumulatedSelectedFaces))
            )
            //              Effect(value: .game(.tap(.began, face)))
          )
          .delay(
            for: .seconds(
              faceIndex == 0
                ? 0.7
                : .random(in: (0.3 * 0.7)...(0.7 * 0.7))
            ),
            scheduler: environment.mainQueue.animation()
          )
          .eraseToEffect()
        )
      }
      effects.append(
        Effect(value: .binding(.set(\.nub.location, .offScreenRight)))
          .receive(on: environment.mainQueue.animate(withDuration: 1))
          .eraseToEffect()
      )

    // todo: isPressed = false

    case let .removedCube(index):
      break
    }

    return .concatenate(effects)
  }
}
.binding(action: /CubePreviewAction.binding)
// TODO: sounds, haptics

public struct CubePreviewView: View {
  @Environment(\.deviceState) var deviceState
  let store: Store<CubePreviewState, CubePreviewAction>

  public init(store: Store<CubePreviewState, CubePreviewAction>) {
    self.store = store
  }

  public var body: some View {
    // TODO: selected word
    WithViewStore(self.store) { viewStore in
      CubeView(
        store: self.store.scope(
          state: CubeSceneView.ViewState.init(preview:),
          action: CubePreviewAction.cubeScene
        )
      )
      .adaptivePadding(
        self.deviceState.idiom == .pad ? .horizontal : [],
        .grid(30)
      )
      .onAppear {
        viewStore.send(.onAppear)
      }
    }
  }
}

extension CubeSceneView.ViewState {
  public init(
    preview: CubePreviewState
  ) {
    self.init(
      cubes: preview.cubes.enumerated().map { x, cubes in
        cubes.enumerated().map { y, cubes in
          cubes.enumerated().map { z, cube in
            let index = LatticePoint.init(x: x, y: y, z: z)
            return CubeNode.ViewState(
              cubeShakeStartedAt: nil,
              index: .init(x: x, y: y, z: z),
              isCriticallySelected: false,
              isInPlay: cube.isInPlay,
              left: .init(
                cubeFace: .init(
                  letter: cube.left.letter,
                  side: .left
                ),
                status: preview.selectedCubeFaces.contains(.init(index: index, side: .left))
                  ? .selected
                  : .deselected
              ),
              right: .init(
                cubeFace: .init(letter: cube.right.letter, side: .right),
                status: preview.selectedCubeFaces.contains(.init(index: index, side: .right))
                  ? .selected
                  : .deselected
              ),
              top: .init(
                cubeFace: .init(letter: cube.top.letter, side: .top),
                status: preview.selectedCubeFaces.contains(.init(index: index, side: .top))
                  ? .selected
                  : .deselected
              )
            )
          }
        }
      },
      isOnLowPowerMode: preview.isOnLowPowerMode,
      nub: preview.nub,
      playedWords: [],
      selectedFaceCount: 0,
      selectedWordIsValid: false, // TODO?
      selectedWordString: "", // TODO?
      settings: preview.settings
    )
  }
}
