import AudioPlayerClient
import Combine
import ComposableArchitecture
import CubeCore
import DictionaryClient
import FeedbackGeneratorClient
import GameCore
import LowPowerModeClient
import PuzzleGen
import SharedModels
import Styleguide
import SwiftUI
import UserDefaultsClient

public struct OnboardingState: Equatable {
  public var alert: AlertState<OnboardingAction.AlertAction>?
  public var game: GameState
  public var presentationStyle: PresentationStyle
  public var step: Step

  public init(
    alert: AlertState<OnboardingAction.AlertAction>? = nil,
    game: GameState = .onboarding,
    presentationStyle: PresentationStyle,
    step: Step = Step.allCases.first!
  ) {
    self.alert = alert
    self.game = game
    self.presentationStyle = presentationStyle
    self.step = step
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

    public static func < (lhs: OnboardingState.Step, rhs: OnboardingState.Step) -> Bool {
      lhs.rawValue < rhs.rawValue
    }
  }
}

public enum OnboardingAction: Equatable {
  case alert(AlertAction)
  case delayedNextStep
  case delegate(DelegateAction)
  case game(GameAction)
  case getStartedButtonTapped
  case onAppear
  case nextButtonTapped
  case skipButtonTapped

  public enum AlertAction: Equatable {
    case confirmSkipButtonTapped
    case dismiss
    case resumeButtonTapped
    case skipButtonTapped
  }

  public enum DelegateAction {
    case getStarted
  }
}

public struct OnboardingEnvironment {
  var audioPlayer: AudioPlayerClient
  var backgroundQueue: AnySchedulerOf<DispatchQueue>
  var dictionary: DictionaryClient
  var feedbackGenerator: FeedbackGeneratorClient
  var lowPowerMode: LowPowerModeClient
  var mainQueue: AnySchedulerOf<DispatchQueue>
  var mainRunLoop: AnySchedulerOf<RunLoop>
  var userDefaults: UserDefaultsClient

  public init(
    audioPlayer: AudioPlayerClient,
    backgroundQueue: AnySchedulerOf<DispatchQueue>,
    dictionary: DictionaryClient,
    feedbackGenerator: FeedbackGeneratorClient,
    lowPowerMode: LowPowerModeClient,
    mainQueue: AnySchedulerOf<DispatchQueue>,
    mainRunLoop: AnySchedulerOf<RunLoop>,
    userDefaults: UserDefaultsClient
  ) {
    self.audioPlayer = audioPlayer.filteredSounds(
      doNotInclude: AudioPlayerClient.Sound.allValidWords
    )
    self.backgroundQueue = backgroundQueue
    self.dictionary = dictionary
    self.feedbackGenerator = feedbackGenerator
    self.lowPowerMode = lowPowerMode
    self.mainQueue = mainQueue
    self.mainRunLoop = mainRunLoop
    self.userDefaults = userDefaults
  }

  var gameEnvironment: GameEnvironment {
    GameEnvironment(
      apiClient: .noop,
      applicationClient: .noop,
      audioPlayer: self.audioPlayer,
      backgroundQueue: self.backgroundQueue,
      build: .noop,
      database: .noop,
      dictionary: self.dictionary,
      feedbackGenerator: self.feedbackGenerator,
      fileClient: .noop,
      gameCenter: .noop,
      lowPowerMode: self.lowPowerMode,
      mainQueue: self.mainQueue,
      mainRunLoop: self.mainRunLoop,
      remoteNotifications: .noop,
      serverConfig: .noop,
      setUserInterfaceStyle: { _ in .none },
      storeKit: .noop,
      userDefaults: self.userDefaults,
      userNotifications: .noop
    )
  }
}

public let onboardingReducer = Reducer<
  OnboardingState,
  OnboardingAction,
  OnboardingEnvironment
> { state, action, environment in
  switch action {
  case .alert(.confirmSkipButtonTapped):
    state.alert = nil
    state.step = OnboardingState.Step.allCases.last!
    return .none

  case .alert(.dismiss):
    state.alert = nil
    return .none

  case .alert(.resumeButtonTapped):
    state.alert = nil
    return .none

  case .alert(.skipButtonTapped):
    state.alert = nil
    return .merge(
      Effect(value: .alert(.confirmSkipButtonTapped))
        .receive(on: ImmediateScheduler.shared.animation())
        .eraseToEffect(),

      environment.audioPlayer.play(.uiSfxTap)
        .fireAndForget()
    )

  case .delayedNextStep:
    state.step.next()
    return .none

  case .delegate(.getStarted):
    return .merge(
      environment.userDefaults
        .setHasShownFirstLaunchOnboarding(true)
        .fireAndForget(),

      environment.audioPlayer.stop(.onboardingBgMusic)
        .fireAndForget(),

      .cancel(id: DelayedNextStepId())
    )

  case .game where state.step.isCongratsStep:
    return .none

  case .game(.submitButtonTapped):
    switch state.step {
    case .step5_SubmitGame where state.game.selectedWordString == "GAME",
      .step8_FindCubes where state.game.selectedWordString == "CUBES",
      .step12_CubeIsShaking where state.game.selectedWordString.isRemove,
      .step16_FindAnyWord where environment.dictionary.contains(state.game.selectedWordString, .en):

      state.step.next()

      return onboardingGameReducer.run(
        &state,
        .game(.submitButtonTapped(nil)),
        environment
      )

    default:
      state.game.selectedWord = []
      return .none
    }

  case let .game(.confirmRemoveCube(index)):
    state.step.next()
    return onboardingGameReducer.run(
      &state,
      .game(.confirmRemoveCube(index)),
      environment
    )

  case let .game(.doubleTap(index: index)):
    guard state.step == .some(.step19_DoubleTapToRemove)
    else { return .none }
    return .init(value: .game(.confirmRemoveCube(index)))

  case let .game(.tap(gestureState, .some(indexedCubeFace))):
    let index =
      isVisible(step: state.step, index: indexedCubeFace.index, side: indexedCubeFace.side)
      ? indexedCubeFace
      : nil

    return onboardingGameReducer.run(
      &state,
      .game(.tap(gestureState, index)),
      environment
    )

  case let .game(.pan(recognizerState, panData)):
    if let indexedCubeFace = panData?.cubeFaceState,
      !isVisible(step: state.step, index: indexedCubeFace.index, side: indexedCubeFace.side)
    {
      return .none
    }
    return onboardingGameReducer.run(
      &state,
      .game(.pan(recognizerState, panData)),
      environment
    )

  case .game:
    return onboardingGameReducer.run(
      &state,
      action,
      environment
    )

  case .getStartedButtonTapped:
    return .init(value: .delegate(.getStarted))

  case .onAppear:
    var firstStepDelay: Int {
      switch state.presentationStyle {
      case .demo, .firstLaunch:
        return 4
      case .help:
        return 2
      }
    }

    return .merge(
      environment.audioPlayer.load(AudioPlayerClient.Sound.allCases)
        .fireAndForget(),

      Effect
        .catching { try environment.dictionary.load(.en) }
        .subscribe(on: environment.backgroundQueue)
        .receive(on: environment.mainQueue)
        .fireAndForget(),

      state.step == OnboardingState.Step.allCases[0]
        ? Effect(value: .delayedNextStep)
          .delay(for: .seconds(firstStepDelay), scheduler: environment.mainQueue.animation())
          .eraseToEffect()
          .cancellable(id: DelayedNextStepId())
        : .none,

      environment.audioPlayer.play(
        state.presentationStyle == .demo
          ? .timedGameBgLoop1
          : .onboardingBgMusic
      )
      .fireAndForget()
    )

  case .nextButtonTapped:
    state.step.next()
    return environment.audioPlayer.play(.uiSfxTap)
      .fireAndForget()

  case .skipButtonTapped:
    guard !environment.userDefaults.hasShownFirstLaunchOnboarding else {
      return .merge(
        Effect(value: .delegate(.getStarted))
          .receive(on: ImmediateScheduler.shared.animation())
          .eraseToEffect(),

        environment.audioPlayer.play(.uiSfxTap)
          .fireAndForget()
      )
    }
    state.alert = .init(
      title: .init("Skip tutorial?"),
      message: .init(
        """
        Are you sure you want to skip the tutorial? It only takes about a minute to complete.

        You can always view it again later in settings.
        """),
      primaryButton: .default(.init("Yes, skip"), send: .skipButtonTapped),
      secondaryButton: .default(.init("No, resume"), send: .resumeButtonTapped),
      onDismiss: .dismiss
    )
    return environment.audioPlayer.play(.uiSfxTap)
      .fireAndForget()
  }
}
.onChange(of: \.game.selectedWordString) { selectedWord, state, _, _ in
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
.onChange(of: \.step) { step, _, _, environment in
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
    return Effect(value: .delayedNextStep)
      .delay(for: 3, scheduler: environment.mainQueue.animation())
      .eraseToEffect()

  case .step6_Congrats,
    .step9_Congrats,
    .step17_Congrats,
    .step20_Congrats:
    return Effect(value: .delayedNextStep)
      .delay(for: 2, scheduler: environment.mainQueue.animation())
      .eraseToEffect()
  }
}

public struct OnboardingView: View {
  @Environment(\.colorScheme) var colorScheme
  let store: Store<OnboardingState, OnboardingAction>
  @ObservedObject var viewStore: ViewStore<ViewState, OnboardingAction>

  struct ViewState: Equatable {
    let isSkipButtonVisible: Bool
    let step: OnboardingState.Step

    init(state: OnboardingState) {
      self.isSkipButtonVisible = state.step != OnboardingState.Step.allCases.last
      self.step = state.step
    }
  }

  public init(store: Store<OnboardingState, OnboardingAction>) {
    self.store = store
    self.viewStore = ViewStore(self.store.scope(state: ViewState.init(state:)))
  }

  public var body: some View {
    ZStack(alignment: .topTrailing) {
      CubeView(
        store: self.store.scope(
          state: cubeSceneViewState(onboardingState:),
          action: { .game(CubeSceneView.ViewAction.to(gameAction: $0)) }
        )
      )
      .opacity(viewStore.step.isFullscreen ? 0 : 1)

      OnboardingStepView(store: self.store)

      if viewStore.isSkipButtonVisible {
        Button("Skip") { viewStore.send(.skipButtonTapped, animation: .default) }
          .adaptiveFont(.matterMedium, size: 18)
          .buttonStyle(PlainButtonStyle())
          .padding([.leading, .trailing])
          .foregroundColor(
            self.colorScheme == .dark
              ? viewStore.step.color
              : Color.isowordsBlack
          )
      }
    }
    .background(
      (self.colorScheme == .dark ? Color.isowordsBlack : viewStore.step.color)
        .ignoresSafeArea()
    )
  }
}

private func cubeSceneViewState(onboardingState: OnboardingState) -> CubeSceneView.ViewState {
  var viewState = CubeSceneView.ViewState(game: onboardingState.game, nub: nil, settings: .init())

  LatticePoint.cubeIndices.forEach { index in
    CubeFace.Side.allCases.forEach { side in
      if !isVisible(step: onboardingState.step, index: index, side: side) {
        viewState.cubes[index][side].letterIsHidden = true
        viewState.cubes[index][side].status = .deselected
      }
    }
  }

  return viewState
}

private func isVisible(
  step: OnboardingState.Step,
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

private let onboardingGameReducer = gameReducer(
  state: \OnboardingState.game,
  action: /OnboardingAction.game,
  environment: { (environment: OnboardingEnvironment) in environment.gameEnvironment },
  isHapticsEnabled: { _ in true }
)

private struct DelayedNextStepId: Hashable {}

#if DEBUG
  struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
      OnboardingView(
        store: Store(
          initialState: .init(presentationStyle: .firstLaunch),
          reducer: .empty,
          environment: ()
        )
      )
    }
  }
#endif
