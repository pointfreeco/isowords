import Bloom
import ComposableArchitecture
import CubeCore
import Dependencies
import HapticsCore
import LowPowerModeClient
import Overture
import SelectionSoundsCore
import SharedModels
import Styleguide
import SwiftUI
import TcaHelpers
import UserSettingsClient

@Feature
public struct CubePreview {
  public struct State {
    @DebugSnapshotTracked var cubes: Puzzle
    @DebugSnapshotTracked var enableGyroMotion: Bool
    @DebugSnapshotTracked var isAnimationReduced: Bool
    @DebugSnapshotTracked var isOnLowPowerMode: Bool
    @DebugSnapshotTracked var moveIndex: Int
    @DebugSnapshotTracked var moves: Moves
    @DebugSnapshotTracked var nub: CubeSceneView.ViewState.NubState
    @DebugSnapshotTracked var selectedCubeFaces: [IndexedCubeFace]

    public init(
      cubes: ArchivablePuzzle,
      isOnLowPowerMode: Bool = false,
      moveIndex: Int,
      moves: Moves,
      nub: CubeSceneView.ViewState.NubState = .init(),
      selectedCubeFaces: [IndexedCubeFace] = []
    ) {
      @Dependency(\.userSettings) var userSettings

      var cubes = Puzzle(archivableCubes: cubes)
      apply(moves: moves[0..<moveIndex], to: &cubes)
      self.cubes = cubes

      self.enableGyroMotion = userSettings.enableGyroMotion
      self.isAnimationReduced = userSettings.enableReducedAnimation
      self.isOnLowPowerMode = isOnLowPowerMode
      self.moveIndex = moveIndex
      self.moves = moves
      self.nub = nub
      self.selectedCubeFaces = selectedCubeFaces
    }

    var cubeScenePreview: CubeSceneView.ViewState {
      let selectedWordString = cubes.string(from: selectedCubeFaces)

      return CubeSceneView.ViewState(
        cubes: cubes.enumerated().map { x, cubes in
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
                  status: selectedCubeFaces.contains(.init(index: index, side: .left))
                    ? .selected
                    : .deselected
                ),
                right: .init(
                  cubeFace: .init(letter: cube.right.letter, side: .right),
                  status: selectedCubeFaces.contains(.init(index: index, side: .right))
                    ? .selected
                    : .deselected
                ),
                top: .init(
                  cubeFace: .init(letter: cube.top.letter, side: .top),
                  status: selectedCubeFaces.contains(.init(index: index, side: .top))
                    ? .selected
                    : .deselected
                )
              )
            }
          }
        },
        enableGyroMotion: enableGyroMotion,
        isOnLowPowerMode: isOnLowPowerMode,
        nub: nub,
        playedWords: [],
        selectedFaceCount: selectedCubeFaces.count,
        selectedWordIsValid: selectedWordString == finalWordString,
        selectedWordString: selectedWordString
      )
    }

    var finalWordString: String? {
      switch moves[moveIndex].type {
      case let .playedWord(faces):
        return cubes.string(from: faces)
      case .removedCube:
        return nil
      }
    }

    var selectedWordString: String { cubes.string(from: selectedCubeFaces) }
    var selectedWordIsFinalWord: Bool { finalWordString == selectedWordString }
    var selectedWordScore: Int? { selectedWordIsFinalWord ? moves[moveIndex].score : nil }
  }

  public enum Action {
    case cubeScene(CubeSceneView.ViewAction)
    case tap
  }

  @Dependency(\.lowPowerMode) var lowPowerMode
  @FeatureEnvironment(\.continuousClock) var clock
  @StoreTaskID var selection
  @Dependency(\.userSettings) var userSettings

  public init() {}

  public var body: some Feature {
    Update { state, action in
      switch action {
      case .cubeScene:
        break

      case .tap:
        state.nub.location = .offScreenRight
        switch state.moves[state.moveIndex].type {
        case let .playedWord(faces):
          state.selectedCubeFaces = faces
        case .removedCube:
          break
        }
        store.addTask { selection.cancel() }
      }
    }
    .onMount { state in
      store.addTask(id: selection) { [move = state.moves[state.moveIndex], nub = state.nub] in
        var nub = nub

        let isOnLowPowerMode = await lowPowerMode.start().first(where: { _ in true }) ?? false
        try store.modify { $0.isOnLowPowerMode = isOnLowPowerMode }

        try await clock.sleep(for: .seconds(1))

        var accumulatedSelectedFaces: [IndexedCubeFace] = []
        switch move.type {
        case let .playedWord(faces):
          for (faceIndex, face) in faces.enumerated() {
            accumulatedSelectedFaces.append(face)
            let moveDuration = Double.random(in: (0.6...0.8))

            // Move the nub to the face
            nub.location = .face(face)
            await store.modify(
              animateWithDuration: moveDuration,
              delay: 0,
              options: .curveEaseInOut
            ) { [nub] in
              $0.nub = nub
            }

            // Pause a bit to allow the nub to animate to the face
            try await clock.sleep(
              for: .seconds(faceIndex == 0 ? moveDuration : 0.5 * moveDuration)
            )

            // Press the nub on the first character
            if faceIndex == 0 {
              nub.isPressed = true
              try withAnimation { _ = try store.modify { $0.nub = nub } }
            }

            // Select the faces that have been tapped so far
            try withAnimation {
              _ = try store.modify { $0.selectedCubeFaces = accumulatedSelectedFaces }
            }
          }

          // Un-press the nub once finished selecting all faces
          nub.isPressed = false
          try store.modify { [nub] in $0.nub = nub }

          // Move the nub off the screen
          nub.location = .offScreenRight
          await store.modify(
            animateWithDuration: 1,
            delay: 0,
            options: .curveEaseInOut
          ) { [nub] in
            $0.nub = nub
          }

        case .removedCube:
          break
        }
      }
    }
    .haptics(
      isEnabled: { _ in userSettings.enableHaptics },
      triggerOnChangeOf: store.selectedCubeFaces
    )
    .selectionSounds(
      contains: { $0.finalWordString?.uppercased() == $1.uppercased() },
      hasBeenPlayed: { _, _ in false },
      puzzle: \.cubes,
      selectedWord: store.selectedCubeFaces
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
            + scoreText
            .baselineOffset(
              (deviceState.idiom == .pad ? 2 : 1) * 16
            )
            .font(
              .custom(
                .matterMedium,
                size: (deviceState.idiom == .pad ? 2 : 1) * 20
              )
            ))
            .adaptiveFont(
              .matterSemiBold,
              size: (deviceState.idiom == .pad ? 2 : 1) * 32
            )
            .opacity(store.selectedWordIsFinalWord ? 1 : 0.5)
            .allowsTightening(true)
            .minimumScaleFactor(0.2)
            .lineLimit(1)
            .transition(.opacity)
            .animation(nil, value: store.selectedWordString)
            .adaptivePadding(.top, .grid(16))
        }

        CubeView(store: store, state: \.cubeScenePreview, action: { .cubeScene($0) })
      }
      .background {
        if !store.isAnimationReduced {
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
