import Bloom
import ComposableArchitecture
import CubeCore
import HapticsCore
import LowPowerModeClient
import Overture
import SelectionSoundsCore
import SharedModels
import SwiftUI
import UserSettings

@Reducer
public struct CubePreview {
  @ObservableState
  public struct State: Equatable {
    var cubes: Puzzle
    var moveIndex: Int
    var moves: Moves
    var nub: CubeSceneView.ViewState.NubState
    var selectedCubeFaces: [IndexedCubeFace]
    @Shared(.userSettings) var userSettings = UserSettings()

    public init(
      cubes: ArchivablePuzzle,
      moveIndex: Int,
      moves: Moves,
      nub: CubeSceneView.ViewState.NubState = .init(),
      selectedCubeFaces: [IndexedCubeFace] = []
    ) {
      var cubes = Puzzle(archivableCubes: cubes)
      apply(moves: moves[0..<moveIndex], to: &cubes)
      self.cubes = cubes
      self.moveIndex = moveIndex
      self.moves = moves
      self.nub = nub
      self.selectedCubeFaces = selectedCubeFaces
    }

    var cubeScenePreview: CubeSceneView.ViewState {
      let selectedWordString = self.cubes.string(from: self.selectedCubeFaces)

      return CubeSceneView.ViewState(
        cubes: self.cubes.enumerated().map { x, cubes in
          cubes.enumerated().map { y, cubes in
            cubes.enumerated().map { z, cube in
              let index = LatticePoint(x: x, y: y, z: z)
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
                  status: self.selectedCubeFaces.contains(.init(index: index, side: .left))
                    ? .selected
                    : .deselected
                ),
                right: .init(
                  cubeFace: .init(letter: cube.right.letter, side: .right),
                  status: self.selectedCubeFaces.contains(.init(index: index, side: .right))
                    ? .selected
                    : .deselected
                ),
                top: .init(
                  cubeFace: .init(letter: cube.top.letter, side: .top),
                  status: self.selectedCubeFaces.contains(.init(index: index, side: .top))
                    ? .selected
                    : .deselected
                )
              )
            }
          }
        },
        enableGyroMotion: self.userSettings.enableGyroMotion,
        nub: self.nub,
        playedWords: [],
        selectedFaceCount: self.selectedCubeFaces.count,
        selectedWordIsValid: selectedWordString == self.finalWordString,
        selectedWordString: selectedWordString
      )
    }

    var finalWordString: String? {
      switch self.moves[self.moveIndex].type {
      case let .playedWord(faces):
        return self.cubes.string(from: faces)
      case .removedCube:
        return nil
      }
    }

    var selectedWordString: String { cubes.string(from: selectedCubeFaces) }
    var selectedWordIsFinalWord: Bool { finalWordString == selectedWordString }
    var selectedWordScore: Int? { selectedWordIsFinalWord ? moves[moveIndex].score : nil }
  }

  public enum Action: BindableAction {
    case binding(BindingAction<State>)
    case cubeScene(CubeSceneView.ViewAction)
    case tap
    case task
  }

  @Dependency(\.mainQueue) var mainQueue

  public init() {}

  public var body: some ReducerOf<Self> {
    BindingReducer()
    Reduce { state, action in
      enum CancelID { case selection }

      switch action {
      case .binding:
        return .none

      case .cubeScene:
        return .none

      case .tap:
        state.nub.location = .offScreenRight
        switch state.moves[state.moveIndex].type {
        case let .playedWord(faces):
          state.selectedCubeFaces = faces
        case .removedCube:
          break
        }
        return .cancel(id: CancelID.selection)

      case .task:
        return .run { [move = state.moves[state.moveIndex], nub = state.nub] send in
          var nub = nub

          try await self.mainQueue.sleep(for: .seconds(1))

          var accumulatedSelectedFaces: [IndexedCubeFace] = []
          switch move.type {
          case let .playedWord(faces):
            for (faceIndex, face) in faces.enumerated() {
              accumulatedSelectedFaces.append(face)
              let moveDuration = Double.random(in: (0.6...0.8))

              // Move the nub to the face
              nub.location = .face(face)
              await send(
                .set(\.nub, nub),
                animateWithDuration: moveDuration,
                delay: 0, options: .curveEaseInOut
              )

              // Pause a bit to allow the nub to animate to the face
              try await self.mainQueue.sleep(
                for: .seconds(faceIndex == 0 ? moveDuration : 0.5 * moveDuration)
              )

              // Press the nub on the first character
              if faceIndex == 0 {
                nub.isPressed = true
                await send(.set(\.nub, nub), animation: .default)
              }

              // Select the faces that have been tapped so far
              await send(.set(\.selectedCubeFaces, accumulatedSelectedFaces), animation: .default)
            }

            // Un-press the nub once finished selecting all faces
            nub.isPressed = false
            await send(.set(\.nub, nub))

            // Move the nub off the screen
            nub.location = .offScreenRight
            await send(
              .set(\.nub, nub),
              animateWithDuration: 1,
              delay: 0,
              options: .curveEaseInOut
            )

          case .removedCube:
            break
          }
        }
        .cancellable(id: CancelID.selection)
      }
    }
    .haptics(
      isEnabled: \.userSettings.enableHaptics,
      triggerOnChangeOf: \.selectedCubeFaces
    )
    .selectionSounds(
      contains: { $0.finalWordString?.uppercased() == $1.uppercased() },
      hasBeenPlayed: { _, _ in false },
      puzzle: \.cubes,
      selectedWord: \.selectedCubeFaces
    )
  }
}

public struct CubePreviewView: View {
  @Environment(\.deviceState) var deviceState
  let store: StoreOf<CubePreview>

  public init(store: StoreOf<CubePreview>) {
    self.store = store
  }

  public var body: some View {
    GeometryReader { proxy in
      ZStack(alignment: .top) {
        if !store.selectedWordString.isEmpty {
          (Text(store.selectedWordString)
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
            .opacity(store.selectedWordIsFinalWord ? 1 : 0.5)
            .allowsTightening(true)
            .minimumScaleFactor(0.2)
            .lineLimit(1)
            .transition(.opacity)
            .animation(nil, value: store.selectedWordString)
            .adaptivePadding(.top, .grid(16))
        }

        CubeView(store: self.store.scope(state: \.cubeScenePreview, action: \.cubeScene))
          .task { await store.send(.task).finish() }
      }
      .background {
        if !store.userSettings.enableReducedAnimation {
          BloomBackground(
            size: proxy.size,
            word: store.selectedWordString
          )
        }
      }
    }
    .onTapGesture {
      UIView.setAnimationsEnabled(false)
      store.send(.tap)
      UIView.setAnimationsEnabled(true)
    }
  }

  var scoreText: Text {
    store.selectedWordScore.map {
      Text(" \($0)")
    } ?? Text("")
  }
}
