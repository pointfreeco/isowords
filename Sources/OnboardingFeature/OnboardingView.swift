import AudioPlayerClient
import ComposableArchitecture
import CubeCore
import Dependencies
import DictionaryClient
import FeedbackGeneratorClient
import GameCore
import HapticsCore
import PuzzleGen
import SharedModels
import Styleguide
import SwiftUI
import UIApplicationClient
import UserDefaultsClient
import UserSettingsClient

@Feature
public struct Onboarding {
  @Feature public struct Alert: Prompt {
    public struct State {
      public init() {}
    }
    public enum Action {
      case skipButtonTapped
    }
  }

  public struct State {
    public var alert: Alert.State?
    public var game: Game.State
    public var presentationStyle: PresentationStyle
    public var step: Step

    public init(
      alert: Alert.State? = nil,
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
    case alert(Alert.Action)
    case cubeScene(CubeSceneView.ViewAction)
    case game(Game.Action)
    case getStartedButtonTapped
    case nextButtonTapped
    case skipButtonTapped
    case submitButtonTapped
  }

  public struct GetStarted: FeatureEventKey {
    public init() {}
  }

  @Dependency(\.audioPlayer) var _audioPlayer
  var audioPlayer: AudioPlayerClient {
    self._audioPlayer.filteredSounds(doNotInclude: AudioPlayerClient.Sound.allValidWords)
  }
  @Dependency(\.dictionary) var dictionary
  @FeatureEnvironment(\.continuousClock) var clock
  @Dependency(\.userDefaults) var userDefaults
  @Dependency(\.userSettings) var userSettings

  @StoreTaskID var delayedNextStep

  public init() {}

  public var body: some Feature {
    Update { state, action in
      switch action {
      case .alert(.skipButtonTapped):
        state.step = State.Step.allCases.last!
        store.addTask {
          self.delayedNextStep.cancel()
          await self.audioPlayer.play(.uiSfxTap)
        }

      case let .cubeScene(viewAction):
        guard !state.step.isCongratsStep else { return }
        switch viewAction {
        case let .doubleTap(index: index):
          guard state.step == .step19_DoubleTapToRemove else { return }
          state.step.next()
          self.sendToGame(.confirmRemoveCube(index))

        case let .pan(recognizerState, panData):
          if let indexedCubeFace = panData?.cubeFaceState,
            !isVisible(step: state.step, index: indexedCubeFace.index, side: indexedCubeFace.side)
          {
            return
          }
          self.sendToGame(.pan(recognizerState, panData))

        case let .tap(gestureState, indexedCubeFace):
          let indexedCubeFace = indexedCubeFace.flatMap {
            isVisible(step: state.step, index: $0.index, side: $0.side) ? $0 : nil
          }
          self.sendToGame(.tap(gestureState, indexedCubeFace))
        }

      case .game:
        break

      case .getStartedButtonTapped:
        self.getStarted()

      case .nextButtonTapped:
        state.step.next()
        store.addTask { await self.audioPlayer.play(.uiSfxTap) }

      case .skipButtonTapped:
        guard !self.userDefaults.hasShownFirstLaunchOnboarding else {
          self.getStarted()
          store.addTask { await self.audioPlayer.play(.uiSfxTap) }
          return
        }
        state.alert = Alert.State()
        store.addTask { await self.audioPlayer.play(.uiSfxTap) }

      case .submitButtonTapped:
        guard !state.step.isCongratsStep else { return }
        switch state.step {
        case .step5_SubmitGame where state.game.selectedWordString == "GAME",
          .step8_FindCubes where state.game.selectedWordString == "CUBES",
          .step12_CubeIsShaking where state.game.selectedWordString.isRemove,
          .step16_FindAnyWord where self.dictionary.contains(state.game.selectedWordString, .en):
          state.step.next()
          self.sendToGame(.submitButtonTapped(reaction: nil))

        default:
          state.game.selectedWord = []
        }
      }
    }
    .ifLet(\.alert) {
      Alert()
    }
    Scope(\.game) {
      Game(startsOnMount: false)
    }
    .transformDependency(\.self) {
      $0.gameOnboarding()
    }
    .haptics(
      isEnabled: { _ in self.userSettings.enableHaptics },
      triggerOnChangeOf: store.game.selectedWord
    )
    .onChange(of: store.game.selectedWordString) { _, selectedWord, state in
      switch state.step {
      case .step4_FindGame where selectedWord == "GAME",
        .step11_FindRemove where selectedWord.isRemove:
        state.step.next()
      case .step5_SubmitGame where selectedWord != "GAME",
        .step12_CubeIsShaking where !selectedWord.isRemove:
        state.step.previous()
      default:
        break
      }
    }
    .onChange(of: store.step) { _, step, _ in
      let delay: Int
      switch step {
      case .step13_Congrats:
        delay = 3
      case .step6_Congrats, .step9_Congrats, .step17_Congrats, .step20_Congrats:
        delay = 2
      default:
        return
      }
      store.addTask {
        try await self.clock.sleep(for: .seconds(delay))
        try await self.nextStep()
      }
    }
    .onMount { state in
      let firstStepDelay: Int
      switch state.presentationStyle {
      case .demo, .firstLaunch:
        firstStepDelay = 4
      case .help:
        firstStepDelay = 2
      }
      let isFirstStep = state.step == State.Step.allCases[0]
      let presentationStyle = state.presentationStyle
      store.addTask(id: self.delayedNextStep) {
        await self.audioPlayer.load(AudioPlayerClient.Sound.allCases)
        _ = try self.dictionary.load(.en)
        await self.audioPlayer.play(
          presentationStyle == .demo ? .timedGameBgLoop1 : .onboardingBgMusic
        )

        if isFirstStep {
          try await self.clock.sleep(for: .seconds(firstStepDelay))
          try await self.nextStep()
        }
      }
    }
  }

  private func getStarted() {
    store.addTask {
      self.delayedNextStep.cancel()
      await self.userDefaults.setHasShownFirstLaunchOnboarding(true)
      await self.audioPlayer.stop(.onboardingBgMusic)
      try await MainActor.run {
        try withAnimation {
          _ = try store.post(GetStarted())
        }
      }
    }
  }

  private func nextStep() async throws {
    try await MainActor.run {
      try withAnimation {
        _ = try store.modify { $0.step.next() }
      }
    }
  }

  private func sendToGame(_ action: Game.Action) {
    store.addTask {
      try await MainActor.run {
        try withAnimation {
          _ = try store.send(.game(action))
        }
      }
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
      CubeView(store: store, state: \.cubeScene, action: { .cubeScene($0) })
        .opacity(store.step.isFullscreen ? 0 : 1)

      OnboardingStepView(store: store)

      if store.isSkipButtonVisible {
        Button("Skip") { withAnimation { _ = store.send(.skipButtonTapped) } }
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

#if DEBUG
  struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
      OnboardingView(
        store: Store(initialState: Onboarding.State(presentationStyle: .firstLaunch)) {
          Onboarding()
        }
      )
    }
  }
#endif
