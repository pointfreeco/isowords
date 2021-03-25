import ComposableArchitecture
import CubeCore
import DictionaryClient
import FeedbackGeneratorClient
import GameCore
import SharedModels
import Styleguide
import SwiftUI

public struct CubePreviewState_: Equatable {
  var game: GameState
  var nub: CubeSceneView.ViewState.NubState
  var moveIndex: Int
}

public enum CubePreviewAction_: Equatable {
  case game(GameAction)
  case binding(BindingAction<CubePreviewState_>)
  case onAppear
}

public struct CubePreviewEnvironment {
  var dictionary: DictionaryClient
  var feedbackGenerator: FeedbackGeneratorClient
  var mainQueue: AnySchedulerOf<DispatchQueue>
  var mainRunLoop: AnySchedulerOf<RunLoop>

  public init(
    dictionary: DictionaryClient,
    feedbackGenerator: FeedbackGeneratorClient,
    mainQueue: AnySchedulerOf<DispatchQueue>,
    mainRunLoop: AnySchedulerOf<RunLoop>
  ) {
    self.dictionary = dictionary
    self.feedbackGenerator = feedbackGenerator
    self.mainQueue = mainQueue
    self.mainRunLoop = mainRunLoop
  }
}

let cubePreviewReducer = Reducer<
CubePreviewState_,
CubePreviewAction_,
CubePreviewEnvironment
>.combine(

  gameReducer(
    state: \CubePreviewState_.game,
    action: /CubePreviewAction_.game,
    environment: {
      .init(
        apiClient: .noop,
        applicationClient: .noop,
        audioPlayer: .noop,
        backgroundQueue: $0.mainQueue,
        build: .noop,
        database: .noop,
        dictionary: $0.dictionary,
        feedbackGenerator: $0.feedbackGenerator,
        fileClient: .noop,
        gameCenter: .noop,
        lowPowerMode: .false,
        mainQueue: $0.mainQueue,
        mainRunLoop: $0.mainRunLoop,
        remoteNotifications: .noop,
        serverConfig: .noop,
        setUserInterfaceStyle: { _ in .none },
        storeKit: .noop,
        userDefaults: .noop,
        userNotifications: .noop
      )
    },
    isHapticsEnabled: { _ in false }
  ),

  .init { state, action, environment in

    switch action {
    case .game:
      return .none

    case .binding:
      return .none

    case .onAppear:
      var effects: [Effect<CubePreviewAction_, Never>] = [
        Effect.none
          .delay(for: 1, scheduler: environment.mainQueue)
          .eraseToEffect()
      ]

      let move = state.game.moves[state.moveIndex]
      switch move.type {
      case let .playedWord(faces):
        for (faceIndex, face) in faces.enumerated() {
          effects.append(
            Effect(value: CubePreviewAction_.binding(.set(\.nub.location, .face(face))))
              .receive(
                on: environment.mainQueue
                  .animate(withDuration: 0.45, options: .curveEaseInOut)
              )
              .eraseToEffect()
          )

          effects.append(
            Effect.merge(
              // Press the nub on the first character
              faceIndex == 0 ? Effect(value: .binding(.set(\.nub.isPressed, true))) : .none,
              // Tap on each face in the word being played
              Effect(value: .game(.tap(.began, face)))
            )
            .delay(
              for: .seconds(
                faceIndex == 0
                  ? 0.45
                  : .random(in: (0.3 * 0.45)...(0.7 * 0.45))
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

      case let .removedCube(index):
        break
      }

      return .concatenate(effects)
    }

  }
)
.binding(action: /CubePreviewAction_.binding)

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
          state: {
            var state = CubeSceneView.ViewState(game: $0.game, nub: $0.nub, settings: .init())
            state.cubes.deselectTheDeselectable()

            return state
          },
          action: { .game(CubeSceneView.ViewAction.to(gameAction: $0)) }
        )
      )
      .adaptivePadding(
        self.deviceState.idiom == .pad ? .horizontal : [],
        .grid(30)
      )

      .onAppear { viewStore.send(.onAppear) }
    }
  }
}

extension CubeSceneView.ViewState.ViewPuzzle {
  mutating func deselectTheDeselectable() {
    LatticePoint.cubeIndices.forEach { index in
      CubeFace.Side.allCases.forEach { face in
        if self[index][face].status == .selectable {
          self[index][face].status = .deselected
        }
      }
    }
  }
}
