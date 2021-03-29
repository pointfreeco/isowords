import AudioPlayerClient
import ComposableArchitecture
import CubeCore
import FeedbackGeneratorClient
import HapticsCore
import SelectionSoundsCore
import SharedModels
import Styleguide
import SwiftUI

public struct CubePreviewState: Equatable {
  var cubes: Puzzle
  var finalWordString: String?
  var isOnLowPowerMode: Bool
  var moves: Moves
  var nub: CubeSceneView.ViewState.NubState
  var moveIndex: Int
  var selectedCubeFaces: [IndexedCubeFace]
  let settings: CubeSceneView.ViewState.Settings

  public init(
    cubes: ArchivablePuzzle,
    finalWordString: String? = nil,
    isOnLowPowerMode: Bool,
    moves: Moves,
    nub: CubeSceneView.ViewState.NubState = .init(),
    moveIndex: Int,
    selectedCubeFaces: [IndexedCubeFace] = [],
    settings: CubeSceneView.ViewState.Settings
  ) {
    self.cubes = .init(archivableCubes: cubes)
    apply(moves: moves[0..<moveIndex], to: &self.cubes)

    self.finalWordString = finalWordString
    self.isOnLowPowerMode = isOnLowPowerMode
    self.moves = moves
    self.nub = nub
    self.moveIndex = moveIndex
    self.selectedCubeFaces = selectedCubeFaces
    self.settings = settings
  }
}

public enum CubePreviewAction: Equatable {
  case binding(BindingAction<CubePreviewState>)
  case cubeScene(CubeSceneView.ViewAction)
  case onAppear
}

public struct CubePreviewEnvironment {
  var audioPlayer: AudioPlayerClient
  var feedbackGenerator: FeedbackGeneratorClient
  var mainQueue: AnySchedulerOf<DispatchQueue>

  public init(
    audioPlayer: AudioPlayerClient,
    feedbackGenerator: FeedbackGeneratorClient,
    mainQueue: AnySchedulerOf<DispatchQueue>
  ) {
    self.audioPlayer = audioPlayer
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
  case .binding:
    return .none

  case .cubeScene:
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
      state.finalWordString = state.cubes.string(from: faces)

      for (faceIndex, face) in faces.enumerated() {
        accumulatedSelectedFaces.append(face)
        let moveDuration = Double.random(in: (0.6 ... 0.8))

        effects.append(
          Effect(value: CubePreviewAction.binding(.set(\.nub.location, .face(face))))
            .receive(
              on: environment.mainQueue
                .animate(withDuration: moveDuration, options: .curveEaseInOut)
            )
            .eraseToEffect()
        )

        effects.append(
          Effect.merge(
            // Press the nub on the first character
            faceIndex == 0 ? Effect(value: .binding(.set(\.nub.isPressed, true))) : .none,

            // Select the faces that have been tapped so far
            Effect(value: .binding(.set(\.selectedCubeFaces, accumulatedSelectedFaces)))
          )
          .delay(
            for: .seconds(
              faceIndex == 0
                ? moveDuration
                : 0.5 * moveDuration
            ),
            scheduler: environment.mainQueue.animation()
          )
          .eraseToEffect()
        )
      }
      effects.append(
        Effect(value: .binding(.set(\.nub.isPressed, false)))
      )
      effects.append(
        Effect(value: .binding(.set(\.nub.location, .offScreenRight)))
          .receive(on: environment.mainQueue.animate(withDuration: 1))
          .eraseToEffect()
      )

    case let .removedCube(index):
      break
    }

    return .concatenate(effects)
  }
}
.binding(action: /CubePreviewAction.binding)
.haptics(
  feedbackGenerator: \.feedbackGenerator,
  isEnabled: { _ in true }, // todo
  triggerOnChangeOf: { $0.selectedCubeFaces }
)
.selectionSounds(
  audioPlayer: \.audioPlayer,
  contains: { state, _, string in
    state.finalWordString?.uppercased() == string.uppercased()
  },
  hasBeenPlayed: { _, _ in false },
  puzzle: \.cubes,
  selectedWord: \.selectedCubeFaces
)
// TODO: cancel effects on dismiss

public struct CubePreviewView: View {
  @Environment(\.deviceState) var deviceState
  let store: Store<CubePreviewState, CubePreviewAction>
  @ObservedObject var viewStore: ViewStore<ViewState, CubePreviewAction>

  struct ViewState: Equatable {
    let selectedWordIsFinalWord: Bool
    let selectedWordScore: Int?
    let selectedWordString: String

    init(state: CubePreviewState) {
      self.selectedWordString = state.cubes.string(from: state.selectedCubeFaces)
      self.selectedWordIsFinalWord = state.finalWordString == self.selectedWordString
      self.selectedWordScore = self.selectedWordIsFinalWord
        ? state.moves[state.moveIndex].score
        : nil
    }
  }

  public init(store: Store<CubePreviewState, CubePreviewAction>) {
    self.store = store
    self.viewStore = ViewStore(self.store.scope(state: ViewState.init(state:)))
  }

  public var body: some View {
    GeometryReader { proxy in
      ZStack(alignment: .top) {
        if !self.viewStore.selectedWordString.isEmpty {
          (Text(self.viewStore.selectedWordString)
            + self.scoreText
            .baselineOffset(
              (self.deviceState.idiom == .pad ? 2 : 1) * 16
            )
            .font(
              .custom(
                .matterMedium,
                size: (self.deviceState.idiom == .pad ? 2 : 1) * 20
              )
            ))
            .adaptiveFont(
              .matterSemiBold,
              size: (self.deviceState.idiom == .pad ? 2 : 1) * 32
            )
            .opacity(self.viewStore.selectedWordIsFinalWord ? 1 : 0.5)
            .allowsTightening(true)
            .minimumScaleFactor(0.2)
            .lineLimit(1)
            .transition(.opacity)
            .animation(nil, value: self.viewStore.selectedWordString)
            .adaptivePadding(.top, .grid(16))
        }

        CubeView(
          store: self.store.scope(
            state: CubeSceneView.ViewState.init(preview:),
            action: CubePreviewAction.cubeScene
          )
        )
        .onAppear {
          self.viewStore.send(.onAppear)
        }
      }
    }
    // TODO: implement bloom and refer to settings to decide if it should be shown
//    .background(
//      BloomBackground(
//        size: proxy.size,
//        store: self.store.scope(
//          state: \.game,
//          action: TrailerAction.game
//        )
//      )
//    )
  }

  var scoreText: Text {
    self.viewStore.selectedWordScore.map {
      Text(" \($0)")
    } ?? Text("")
  }
}

extension CubeSceneView.ViewState {
  public init(preview state: CubePreviewState) {
    let selectedWordString = state.cubes.string(from: state.selectedCubeFaces)

    self.init(
      cubes: state.cubes.enumerated().map { x, cubes in
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
                status: state.selectedCubeFaces.contains(.init(index: index, side: .left))
                  ? .selected
                  : .deselected
              ),
              right: .init(
                cubeFace: .init(letter: cube.right.letter, side: .right),
                status: state.selectedCubeFaces.contains(.init(index: index, side: .right))
                  ? .selected
                  : .deselected
              ),
              top: .init(
                cubeFace: .init(letter: cube.top.letter, side: .top),
                status: state.selectedCubeFaces.contains(.init(index: index, side: .top))
                  ? .selected
                  : .deselected
              )
            )
          }
        }
      },
      isOnLowPowerMode: state.isOnLowPowerMode,
      nub: state.nub,
      playedWords: [],
      selectedFaceCount: 0,
      selectedWordIsValid: selectedWordString == state.finalWordString,
      selectedWordString: selectedWordString,
      settings: state.settings
    )
  }
}
