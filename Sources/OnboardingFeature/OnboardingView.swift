import AudioPlayerClient
import Combine
import ComposableArchitecture
import CubeCore
import DictionaryClient
import FeedbackGeneratorClient
import GameCore
import PuzzleGen
import SharedModels
import Styleguide
import SwiftUI
import UIApplicationClient
import UserDefaultsClient

@Reducer
public struct Onboarding {
  @ObservableState
  public struct State: Equatable {
    @Presents public var alert: AlertState<Action.Alert>?
    public var game: Game.State
    public var presentationStyle: PresentationStyle
    public var step: Step

    public init(
      alert: AlertState<Action.Alert>? = nil,
      game: Game.State = .onboarding,
      presentationStyle: PresentationStyle,
      step: Step = Step.allCases.first!
    ) {
      self.alert = alert
      self.game = game
      self.presentationStyle = presentationStyle
      self.step = step
    }

    fileprivate var isSkipButtonVisible: Bool {
      self.step != Onboarding.State.Step.allCases.last
    }

    fileprivate var cubeScene: CubeSceneView.ViewState {
      var viewState = CubeSceneView.ViewState(game: self.game, nub: nil)

      LatticePoint.cubeIndices.forEach { index in
        CubeFace.Side.allCases.forEach { side in
          if !isVisible(step: self.step, index: index, side: side) {
            viewState.cubes[index][side].letterIsHidden = true
            viewState.cubes[index][side].status = .deselected
          }
        }
      }

      return viewState
    }

    public enum PresentationStyle {
      case demo
      case firstLaunch
      case help
    }

    public enum Step: Int, CaseIterable, Comparable, Equatable {
      case step1_Welcome
      case step2_FindWordsOnCube
      case step3_ConnectLettersTouching
      case step4_FindGame
      case step5_SubmitGame
      case step6_Congrats
      case step7_BiggerCube
      case step8_FindCubes
      case step9_Congrats
      case step10_CubeDisappear
      case step11_FindRemove
      case step12_CubeIsShaking
      case step13_Congrats
      case step14_LettersRevealed
      case step15_FullCube
      case step16_FindAnyWord
      case step17_Congrats
      case step18_OneLastThing
      case step19_DoubleTapToRemove
      case step20_Congrats
      case step21_PlayAGameYourself

      mutating func next() {
        self = Self(rawValue: self.rawValue + 1) ?? Self.allCases.last!
      }

      mutating func previous() {
        self = Self(rawValue: self.rawValue - 1) ?? Self.allCases.first!
      }

      var isFullscreen: Bool {
        switch self {
        case .step1_Welcome,
          .step2_FindWordsOnCube,
          .step3_ConnectLettersTouching,
          .step7_BiggerCube,
          .step10_CubeDisappear,
          .step14_LettersRevealed,
          .step15_FullCube,
          .step18_OneLastThing,
          .step21_PlayAGameYourself:
          return true

        case .step4_FindGame,
          .step5_SubmitGame,
          .step6_Congrats,
          .step8_FindCubes,
          .step9_Congrats,
          .step11_FindRemove,
          .step12_CubeIsShaking,
          .step13_Congrats,
          .step16_FindAnyWord,
          .step17_Congrats,
          .step19_DoubleTapToRemove,
          .step20_Congrats:
          return false
        }
      }

      var isCongratsStep: Bool {
        switch self {
        case .step6_Congrats,
          .step9_Congrats,
          .step13_Congrats,
          .step17_Congrats,
          .step20_Congrats:
          return true

        case .step1_Welcome,
          .step2_FindWordsOnCube,
          .step3_ConnectLettersTouching,
          .step4_FindGame,
          .step5_SubmitGame,
          .step7_BiggerCube,
          .step8_FindCubes,
          .step10_CubeDisappear,
          .step11_FindRemove,
          .step12_CubeIsShaking,
          .step14_LettersRevealed,
          .step15_FullCube,
          .step16_FindAnyWord,
          .step18_OneLastThing,
          .step19_DoubleTapToRemove,
          .step21_PlayAGameYourself:
          return false
        }
      }

      public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
      }
    }
  }

  public enum Action {
    case alert(PresentationAction<Alert>)
    case delayedNextStep
    case delegate(Delegate)
    case game(Game.Action)
    case getStartedButtonTapped
    case nextButtonTapped
    case skipButtonTapped
    case task

    @CasePathable
    public enum Alert {
      case skipButtonTapped
    }

    @CasePathable
    public enum Delegate {
      case getStarted
    }
  }

  @Dependency(\.audioPlayer) var _audioPlayer
  var audioPlayer: AudioPlayerClient {
    self._audioPlayer.filteredSounds(doNotInclude: AudioPlayerClient.Sound.allValidWords)
  }
  @Dependency(\.dictionary) var dictionary
  @Dependency(\.feedbackGenerator) var feedbackGenerator
  @Dependency(\.mainQueue) var mainQueue
  @Dependency(\.userDefaults) var userDefaults
  @Dependency(\.userSettings) var userSettings

  public init() {}

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .alert(.dismiss):
        return .none

      case .alert(.presented(.skipButtonTapped)):
        state.step = State.Step.allCases.last!
        return .run { _ in
          await self.audioPlayer.play(.uiSfxTap)
          Task.cancel(id: CancelID.delayedNextStep)
        }

      case .delayedNextStep:
        state.step.next()
        return .none

      case .delegate(.getStarted):
        return .run { _ in
          await self.userDefaults.setHasShownFirstLaunchOnboarding(true)
          await self.audioPlayer.stop(.onboardingBgMusic)
          Task.cancel(id: CancelID.delayedNextStep)
        }

      case .game where state.step.isCongratsStep:
        return .none

      case .game(.submitButtonTapped):
        switch state.step {
        case .step5_SubmitGame where state.game.selectedWordString == "GAME",
          .step8_FindCubes where state.game.selectedWordString == "CUBES",
          .step12_CubeIsShaking where state.game.selectedWordString.isRemove,
          .step16_FindAnyWord where self.dictionary.contains(state.game.selectedWordString, .en):

          state.step.next()

          return self.gameReducer.reduce(
            into: &state,
            action: .game(.submitButtonTapped(reaction: nil))
          )

        default:
          state.game.selectedWord = []
          return .none
        }

      case let .game(.confirmRemoveCube(index)):
        state.step.next()
        return self.gameReducer.reduce(into: &state, action: .game(.confirmRemoveCube(index)))

      case let .game(.doubleTap(index: index)):
        guard state.step == .some(.step19_DoubleTapToRemove)
        else { return .none }
        return .send(.game(.confirmRemoveCube(index)))

      case let .game(.tap(gestureState, .some(indexedCubeFace))):
        let index =
          isVisible(step: state.step, index: indexedCubeFace.index, side: indexedCubeFace.side)
          ? indexedCubeFace
          : nil

        return self.gameReducer.reduce(into: &state, action: .game(.tap(gestureState, index)))

      case let .game(.pan(recognizerState, panData)):
        if let indexedCubeFace = panData?.cubeFaceState,
          !isVisible(step: state.step, index: indexedCubeFace.index, side: indexedCubeFace.side)
        {
          return .none
        }
        return self.gameReducer.reduce(into: &state, action: .game(.pan(recognizerState, panData)))

      case .game:
        return self.gameReducer.reduce(into: &state, action: action)

      case .getStartedButtonTapped:
        return .send(.delegate(.getStarted))

      case .nextButtonTapped:
        state.step.next()
        return .run { _ in await self.audioPlayer.play(.uiSfxTap) }

      case .skipButtonTapped:
        guard !self.userDefaults.hasShownFirstLaunchOnboarding else {
          return .run { send in
            await send(.delegate(.getStarted), animation: .default)
            await self.audioPlayer.play(.uiSfxTap)
          }
        }
        state.alert = AlertState {
          TextState("Skip tutorial?")
        } actions: {
          ButtonState(action: .send(.skipButtonTapped, animation: .default)) {
            TextState("Yes, skip")
          }
          ButtonState(role: .cancel) {
            TextState("No, resume")
          }
        } message: {
          TextState(
            """
            Are you sure you want to skip the tutorial? It only takes about a minute to complete.

            You can always view it again later in settings.
            """
          )
        }
        return .run { _ in await self.audioPlayer.play(.uiSfxTap) }

      case .task:
        let firstStepDelay: Int = {
          switch state.presentationStyle {
          case .demo, .firstLaunch:
            return 4
          case .help:
            return 2
          }
        }()

        return .run { [step = state.step, presentationStyle = state.presentationStyle] send in
          await self.audioPlayer.load(AudioPlayerClient.Sound.allCases)
          _ = try self.dictionary.load(.en)
          await self.audioPlayer.play(
            presentationStyle == .demo ? .timedGameBgLoop1 : .onboardingBgMusic
          )

          if step == State.Step.allCases[0] {
            try await self.mainQueue.sleep(for: .seconds(firstStepDelay))
            await send(.delayedNextStep, animation: .default)
          }
        }
        .cancellable(id: CancelID.delayedNextStep)
      }
    }
    .ifLet(\.$alert, action: \.alert)
    .onChange(of: \.game.selectedWordString) { _, selectedWord in
      Reduce { state, _ in
        switch state.step {
        case .step4_FindGame where selectedWord == "GAME",
          .step11_FindRemove where selectedWord.isRemove:
          state.step.next()
          return .none
        case .step5_SubmitGame where selectedWord != "GAME",
          .step12_CubeIsShaking where !selectedWord.isRemove:
          state.step.previous()
          return .none
        default:
          return .none
        }
      }
    }
    .onChange(of: \.step) { _, step in
      Reduce { _, _ in
        switch step {
        case .step1_Welcome,
          .step2_FindWordsOnCube,
          .step3_ConnectLettersTouching,
          .step4_FindGame,
          .step5_SubmitGame,
          .step7_BiggerCube,
          .step8_FindCubes,
          .step10_CubeDisappear,
          .step11_FindRemove,
          .step12_CubeIsShaking,
          .step14_LettersRevealed,
          .step15_FullCube,
          .step16_FindAnyWord,
          .step18_OneLastThing,
          .step19_DoubleTapToRemove,
          .step21_PlayAGameYourself:
          return .none

        case .step13_Congrats:
          return .run { send in
            try await self.mainQueue.sleep(for: .seconds(3))
            await send(.delayedNextStep, animation: .default)
          }

        case .step6_Congrats,
          .step9_Congrats,
          .step17_Congrats,
          .step20_Congrats:
          return .run { send in
            try await self.mainQueue.sleep(for: .seconds(2))
            await send(.delayedNextStep, animation: .default)
          }
        }
      }
    }
  }

  var gameReducer: some ReducerOf<Self> {
    Scope(state: \.game, action: \.game) {
      Game()
        .haptics(
          isEnabled: { _ in self.userSettings.enableHaptics },
          triggerOnChangeOf: \.selectedWord
        )
    }
    .transformDependency(\.self) {
      $0.gameOnboarding()
    }
  }
}

public struct OnboardingView: View {
  @Environment(\.colorScheme) var colorScheme
  let store: StoreOf<Onboarding>

  public init(store: StoreOf<Onboarding>) {
    self.store = store
  }

  public var body: some View {
    ZStack(alignment: .topTrailing) {
      CubeView(store: store.scope(state: \.cubeScene, action: \.game.cubeScene))
        .opacity(store.step.isFullscreen ? 0 : 1)

      OnboardingStepView(store: store)

      if store.isSkipButtonVisible {
        Button("Skip") { store.send(.skipButtonTapped, animation: .default) }
          .adaptiveFont(.matterMedium, size: 18)
          .buttonStyle(PlainButtonStyle())
          .padding(.horizontal)
          .foregroundColor(
            self.colorScheme == .dark
              ? store.step.color
              : Color.isowordsBlack
          )
      }
    }
    .background(
      (self.colorScheme == .dark ? Color.isowordsBlack : store.step.color)
        .ignoresSafeArea()
    )
  }
}

private func isVisible(
  step: Onboarding.State.Step,
  index: LatticePoint,
  side: CubeFace.Side
) -> Bool {

  if step < .step8_FindCubes {
    return index == .init(x: .one, y: .two, z: .two) && side == .left
      || index == .init(x: .two, y: .two, z: .two) && side == .left
      || index == .init(x: .two, y: .two, z: .two) && side == .right
      || index == .init(x: .two, y: .two, z: .one) && side == .right
  } else if step < .step11_FindRemove {
    return index == .init(x: .one, y: .two, z: .two)
      || index == .init(x: .two, y: .two, z: .two)
      || index == .init(x: .two, y: .two, z: .one)
      || index == .init(x: .one, y: .two, z: .one)
  } else if step < .step13_Congrats {
    return index.x >= .one && index.y >= .one && index.z >= .one
  } else if step < .step16_FindAnyWord {
    return index.x >= .one && index.y >= .one && index.z >= .one
      || index == .init(x: .two, y: .two, z: .zero) && side == .left
  }

  return true
}

extension String {
  var isRemove: Bool {
    self == "REMOVE" || self == "REMOVES"
  }
}

private enum CancelID {
  case delayedNextStep
}

#if DEBUG
  struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
      OnboardingView(
        store: Store(initialState: .init(presentationStyle: .firstLaunch)) {
        }
      )
    }
  }
#endif
