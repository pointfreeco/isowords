import ComposableArchitecture
import CubeCore
import FeedbackGeneratorClient
import SharedModels
import Styleguide
import SwiftUI

extension CubeSceneView.ViewState {
  public init(
    preview: CubePreviewState_
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
      selectedWordIsValid: false,
      selectedWordString: "",
      settings: preview.settings
    )
  }
}

public struct CubePreviewState_: Equatable {
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

public enum CubePreviewAction_: Equatable {
//  case game(GameAction)
  case cube(CubeSceneView.ViewAction)
  case binding(BindingAction<CubePreviewState_>)
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
CubePreviewState_,
CubePreviewAction_,
CubePreviewEnvironment
>.combine(



//  gameReducer(
//    state: \CubePreviewState_.game,
//    action: /CubePreviewAction_.game,
//    environment: {
//      .init(
//        apiClient: .noop,
//        applicationClient: .noop,
//        audioPlayer: .noop,
//        backgroundQueue: $0.mainQueue,
//        build: .noop,
//        database: .noop,
//        dictionary: $0.dictionary,
//        feedbackGenerator: $0.feedbackGenerator,
//        fileClient: .noop,
//        gameCenter: .noop,
//        lowPowerMode: .false,
//        mainQueue: $0.mainQueue,
//        mainRunLoop: $0.mainRunLoop,
//        remoteNotifications: .noop,
//        serverConfig: .noop,
//        setUserInterfaceStyle: { _ in .none },
//        storeKit: .noop,
//        userDefaults: .noop,
//        userNotifications: .noop
//      )
//    },
//    isHapticsEnabled: { _ in false }
//  ),

  .init { state, action, environment in
    switch action {
//    case .game:
//      return .none

    case .cube:
      return .none

    case .binding:
      return .none

    case .onAppear:
      var effects: [Effect<CubePreviewAction_, Never>] = [
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
            Effect(value: CubePreviewAction_.binding(.set(\.nub.location, .face(face))))
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
              Effect<CubePreviewAction_, Never>.init(
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
)
.binding(action: /CubePreviewAction_.binding)
// TODO: sounds, haptics

public struct CubePreviewView: View {
  @Environment(\.deviceState) var deviceState
  let store: Store<CubePreviewState_, CubePreviewAction_>

  public init(store: Store<CubePreviewState_, CubePreviewAction_>) {
    self.store = store
  }

  public var body: some View {
    WithViewStore(self.store) { viewStore in
      CubeView(
        store: self.store.scope(
          state: CubeSceneView.ViewState.init(preview:),
          action: CubePreviewAction_.cube
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
