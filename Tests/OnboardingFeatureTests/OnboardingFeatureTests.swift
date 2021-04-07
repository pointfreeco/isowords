import ComposableArchitecture
import SharedModels
import XCTest

@testable import OnboardingFeature

class OnboardingFeatureTests: XCTestCase {
  let mainQueue = DispatchQueue.test

  func testBasics_FirstLaunch() {
    var isFirstLaunchOnboardingKeySet = false
    
    var environment = OnboardingEnvironment.failing
    environment.audioPlayer = .noop
    environment.backgroundQueue = .immediate
    environment.dictionary.load = { _ in true }
    environment.dictionary.contains = { word, _ in
      ["GAME", "CUBES", "REMOVE", "WORD"].contains(word)
    }
    environment.feedbackGenerator = .noop
    environment.mainRunLoop = .immediate
    environment.mainQueue = self.mainQueue.eraseToAnyScheduler()
    environment.userDefaults.setBool = { value, key in
      .fireAndForget {
        XCTAssertEqual(key, "hasShownFirstLaunchOnboardingKey")
        XCTAssertEqual(value, true)
        isFirstLaunchOnboardingKeySet = true
      }
    }

    let store = TestStore(
      initialState: OnboardingState(presentationStyle: .firstLaunch),
      reducer: onboardingReducer,
      environment: environment
    )

    store.send(.onAppear)

    self.mainQueue.advance(by: .seconds(4))
    store.receive(.delayedNextStep) {
      $0.step = .step2_FindWordsOnCube
    }

    store.send(.nextButtonTapped) {
      $0.step = .step3_ConnectLettersTouching
    }

    store.send(.nextButtonTapped) {
      $0.step = .step4_FindGame
    }

    // Find and submit "GAME"
    store.send(.game(.tap(.began, .init(index: .init(x: .one, y: .two, z: .two), side: .left)))) {
      $0.game.optimisticallySelectedFace = .init(index: .init(x: .one, y: .two, z: .two), side: .left)
      $0.game.selectedWord.append(.init(index: .init(x: .one, y: .two, z: .two), side: .left))
    }
    store.send(.game(.tap(.began, .init(index: .init(x: .two, y: .two, z: .two), side: .left)))) {
      $0.game.optimisticallySelectedFace = .init(index: .init(x: .two, y: .two, z: .two), side: .left)
      $0.game.selectedWord.append(.init(index: .init(x: .two, y: .two, z: .two), side: .left))
    }
    store.send(.game(.tap(.began, .init(index: .init(x: .two, y: .two, z: .two), side: .right)))) {
      $0.game.optimisticallySelectedFace = .init(index: .init(x: .two, y: .two, z: .two), side: .right)
      $0.game.selectedWord.append(.init(index: .init(x: .two, y: .two, z: .two), side: .right))
    }
    store.send(.game(.tap(.began, .init(index: .init(x: .two, y: .two, z: .one), side: .right)))) {
      $0.step = .step5_SubmitGame
      $0.game.optimisticallySelectedFace = .init(index: .init(x: .two, y: .two, z: .one), side: .right)
      $0.game.selectedWord.append(.init(index: .init(x: .two, y: .two, z: .one), side: .right))
      $0.game.selectedWordIsValid = true
    }
    store.send(.game(.submitButtonTapped(nil))) {
      $0.game.cubes[.one][.two][.two].left.useCount += 1
      $0.game.cubes[.two][.two][.two].left.useCount += 1
      $0.game.cubes[.two][.two][.two].right.useCount += 1
      $0.game.cubes[.two][.two][.one].right.useCount += 1
      $0.game.moves.append(
        .init(
          playedAt: environment.mainRunLoop.now.date,
          playerIndex: nil,
          reactions: nil,
          score: 36,
          type: .playedWord([
            .init(index: .init(x: .one, y: .two, z: .two), side: .left),
            .init(index: .init(x: .two, y: .two, z: .two), side: .left),
            .init(index: .init(x: .two, y: .two, z: .two), side: .right),
            .init(index: .init(x: .two, y: .two, z: .one), side: .right),
          ])
        )
      )
      $0.game.selectedWord = []
      $0.game.selectedWordIsValid = false
      $0.step = .step6_Congrats
    }

    // Wait a moment to automatically go to the next step
    self.mainQueue.advance(by: .seconds(2))
    store.receive(.delayedNextStep) {
      $0.step = .step7_BiggerCube
    }

    store.send(.nextButtonTapped) {
      $0.step = .step8_FindCubes
    }

    // Find and submit the word "CUBES"
    store.send(.game(.tap(.began, .init(index: .init(x: .one, y: .two, z: .two), side: .top)))) {
      $0.game.optimisticallySelectedFace = .init(index: .init(x: .one, y: .two, z: .two), side: .top)
      $0.game.selectedWord.append(.init(index: .init(x: .one, y: .two, z: .two), side: .top))
    }
    store.send(.game(.tap(.began, .init(index: .init(x: .one, y: .two, z: .one), side: .top)))) {
      $0.game.optimisticallySelectedFace = .init(index: .init(x: .one, y: .two, z: .one), side: .top)
      $0.game.selectedWord.append(.init(index: .init(x: .one, y: .two, z: .one), side: .top))
    }
    store.send(.game(.tap(.began, .init(index: .init(x: .two, y: .two, z: .two), side: .top)))) {
      $0.game.optimisticallySelectedFace = .init(index: .init(x: .two, y: .two, z: .two), side: .top)
      $0.game.selectedWord.append(.init(index: .init(x: .two, y: .two, z: .two), side: .top))
    }
    store.send(.game(.tap(.began, .init(index: .init(x: .two, y: .two, z: .one), side: .right)))) {
      $0.game.optimisticallySelectedFace = .init(index: .init(x: .two, y: .two, z: .one), side: .right)
      $0.game.selectedWord.append(.init(index: .init(x: .two, y: .two, z: .one), side: .right))
    }
    store.send(.game(.tap(.began, .init(index: .init(x: .two, y: .two, z: .one), side: .top)))) {
      $0.game.optimisticallySelectedFace = .init(index: .init(x: .two, y: .two, z: .one), side: .top)
      $0.game.selectedWord.append(.init(index: .init(x: .two, y: .two, z: .one), side: .top))
      $0.game.selectedWordIsValid = true
    }
    store.send(.game(.submitButtonTapped(nil))) {
      $0.game.cubes[.one][.two][.two].top.useCount += 1
      $0.game.cubes[.one][.two][.one].top.useCount += 1
      $0.game.cubes[.two][.two][.two].top.useCount += 1
      $0.game.cubes[.two][.two][.one].right.useCount += 1
      $0.game.cubes[.two][.two][.one].top.useCount += 1
      $0.game.moves.append(
        .init(
          playedAt: environment.mainRunLoop.now.date,
          playerIndex: nil,
          reactions: nil,
          score: 110,
          type: .playedWord([
            .init(index: .init(x: .one, y: .two, z: .two), side: .top),
            .init(index: .init(x: .one, y: .two, z: .one), side: .top),
            .init(index: .init(x: .two, y: .two, z: .two), side: .top),
            .init(index: .init(x: .two, y: .two, z: .one), side: .right),
            .init(index: .init(x: .two, y: .two, z: .one), side: .top),
          ])
        )
      )
      $0.game.selectedWord = []
      $0.game.selectedWordIsValid = false
      $0.step = .step9_Congrats
    }

    // Wait a moment to automatically go to the next step
    self.mainQueue.advance(by: .seconds(2))
    store.receive(.delayedNextStep) {
      $0.step = .step10_CubeDisappear
    }

    store.send(.nextButtonTapped) {
      $0.step = .step11_FindRemove
    }

    // Find and submit the word "REMOVE"
    store.send(.game(.tap(.began, .init(index: .init(x: .one, y: .one, z: .two), side: .left)))) {
      $0.game.optimisticallySelectedFace = .init(index: .init(x: .one, y: .one, z: .two), side: .left)
      $0.game.selectedWord.append(.init(index: .init(x: .one, y: .one, z: .two), side: .left))
    }
    store.send(.game(.tap(.began, .init(index: .init(x: .two, y: .one, z: .two), side: .left)))) {
      $0.game.optimisticallySelectedFace = .init(index: .init(x: .two, y: .one, z: .two), side: .left)
      $0.game.selectedWord.append(.init(index: .init(x: .two, y: .one, z: .two), side: .left))
    }
    store.send(.game(.tap(.began, .init(index: .init(x: .two, y: .two, z: .two), side: .right)))) {
      $0.game.optimisticallySelectedFace = .init(index: .init(x: .two, y: .two, z: .two), side: .right)
      $0.game.selectedWord.append(.init(index: .init(x: .two, y: .two, z: .two), side: .right))
    }
    store.send(.game(.tap(.began, .init(index: .init(x: .two, y: .one, z: .two), side: .right)))) {
      $0.game.optimisticallySelectedFace = .init(index: .init(x: .two, y: .one, z: .two), side: .right)
      $0.game.selectedWord.append(.init(index: .init(x: .two, y: .one, z: .two), side: .right))
    }
    store.send(.game(.tap(.began, .init(index: .init(x: .two, y: .one, z: .one), side: .right)))) {
      $0.game.optimisticallySelectedFace = .init(index: .init(x: .two, y: .one, z: .one), side: .right)
      $0.game.selectedWord.append(.init(index: .init(x: .two, y: .one, z: .one), side: .right))
    }
    store.send(.game(.tap(.began, .init(index: .init(x: .two, y: .two, z: .one), side: .right)))) {
      $0.game.cubeStartedShakingAt = environment.mainRunLoop.now.date
      $0.game.optimisticallySelectedFace = .init(index: .init(x: .two, y: .two, z: .one), side: .right)
      $0.game.selectedWord.append(.init(index: .init(x: .two, y: .two, z: .one), side: .right))
      $0.game.selectedWordIsValid = true
      $0.step = .step12_CubeIsShaking
    }
    store.send(.game(.submitButtonTapped(nil))) {
      $0.game.cubeStartedShakingAt = nil
      $0.game.cubes[.one][.one][.two].left.useCount += 1
      $0.game.cubes[.two][.one][.two].left.useCount += 1
      $0.game.cubes[.two][.two][.two].right.useCount += 1
      $0.game.cubes[.two][.one][.two].right.useCount += 1
      $0.game.cubes[.two][.one][.one].right.useCount += 1
      $0.game.cubes[.two][.two][.one].right.useCount += 1
      $0.game.moves.append(
        .init(
          playedAt: environment.mainRunLoop.now.date,
          playerIndex: nil,
          reactions: nil,
          score: 252,
          type: .playedWord([
            .init(index: .init(x: .one, y: .one, z: .two), side: .left),
            .init(index: .init(x: .two, y: .one, z: .two), side: .left),
            .init(index: .init(x: .two, y: .two, z: .two), side: .right),
            .init(index: .init(x: .two, y: .one, z: .two), side: .right),
            .init(index: .init(x: .two, y: .one, z: .one), side: .right),
            .init(index: .init(x: .two, y: .two, z: .one), side: .right),
          ])
        )
      )
      $0.game.selectedWord = []
      $0.game.selectedWordIsValid = false
      $0.step = .step13_Congrats
    }

    self.mainQueue.advance(by: .seconds(3))
    store.receive(.delayedNextStep) {
      $0.step = .step14_LettersRevealed
    }

    store.send(.nextButtonTapped) {
      $0.step = .step15_FullCube
    }
    store.send(.nextButtonTapped) {
      $0.step = .step16_FindAnyWord
    }

    // Find the word "WORD"
    store.send(.game(.tap(.began, .init(index: .init(x: .zero, y: .zero, z: .two), side: .left)))) {
      $0.game.optimisticallySelectedFace = .init(index: .init(x: .zero, y: .zero, z: .two), side: .left)
      $0.game.selectedWord.append(.init(index: .init(x: .zero, y: .zero, z: .two), side: .left))
    }
    store.send(.game(.tap(.began, .init(index: .init(x: .one, y: .zero, z: .two), side: .left)))) {
      $0.game.optimisticallySelectedFace = .init(index: .init(x: .one, y: .zero, z: .two), side: .left)
      $0.game.selectedWord.append(.init(index: .init(x: .one, y: .zero, z: .two), side: .left))
    }
    store.send(.game(.tap(.began, .init(index: .init(x: .two, y: .zero, z: .two), side: .left)))) {
      $0.game.optimisticallySelectedFace = .init(index: .init(x: .two, y: .zero, z: .two), side: .left)
      $0.game.selectedWord.append(.init(index: .init(x: .two, y: .zero, z: .two), side: .left))
    }
    store.send(.game(.tap(.began, .init(index: .init(x: .two, y: .zero, z: .two), side: .right)))) {
      $0.game.optimisticallySelectedFace = .init(index: .init(x: .two, y: .zero, z: .two), side: .right)
      $0.game.selectedWord.append(.init(index: .init(x: .two, y: .zero, z: .two), side: .right))
      $0.game.selectedWordIsValid = true
    }
    store.send(.game(.submitButtonTapped(nil))) {
      $0.game.cubes[.zero][.zero][.two].left.useCount += 1
      $0.game.cubes[.one][.zero][.two].left.useCount += 1
      $0.game.cubes[.two][.zero][.two].left.useCount += 1
      $0.game.cubes[.two][.zero][.two].right.useCount += 1
      $0.game.moves.append(
        .init(
          playedAt: environment.mainRunLoop.now.date,
          playerIndex: nil,
          reactions: nil,
          score: 44,
          type: .playedWord([
            .init(index: .init(x: .zero, y: .zero, z: .two), side: .left),
            .init(index: .init(x: .one, y: .zero, z: .two), side: .left),
            .init(index: .init(x: .two, y: .zero, z: .two), side: .left),
            .init(index: .init(x: .two, y: .zero, z: .two), side: .right),
          ])
        )
      )
      $0.game.selectedWord = []
      $0.game.selectedWordIsValid = false
      $0.step = .step17_Congrats
    }

    self.mainQueue.advance(by: .seconds(2))
    store.receive(.delayedNextStep) {
      $0.step = .step18_OneLastThing
    }

    store.send(.nextButtonTapped) {
      $0.step = .step19_DoubleTapToRemove
    }

    store.send(.game(.doubleTap(index: .init(x: .two, y: .two, z: .two))))
    store.receive(.game(.confirmRemoveCube(.init(x: .two, y: .two, z: .two)))) {
      $0.game.cubes[.two][.two][.two].wasRemoved = true
      $0.game.moves.append(
        .init(
          playedAt: environment.mainRunLoop.now.date,
          playerIndex: nil,
          reactions: nil,
          score: 0,
          type: .removedCube(.init(x: .two, y: .two, z: .two))
        )
      )
      $0.step = .step20_Congrats
    }

    self.mainQueue.advance(by: .seconds(2))
    store.receive(.delayedNextStep) {
      $0.step = .step21_PlayAGameYourself
    }

    store.send(.getStartedButtonTapped)
    store.receive(.delegate(.getStarted))

    XCTAssertEqual(isFirstLaunchOnboardingKeySet, true)
  }

  func testSkip_HasSeenOnboardingBefore() {
    var isFirstLaunchOnboardingKeySet = false

    var environment = OnboardingEnvironment.failing
    environment.audioPlayer = .noop
    environment.backgroundQueue = .immediate
    environment.dictionary.load = { _ in true }
    environment.mainQueue = self.mainQueue.eraseToAnyScheduler()
    environment.userDefaults.boolForKey = { key in
      XCTAssertEqual(key, "hasShownFirstLaunchOnboardingKey")
      return true
    }
    environment.userDefaults.setBool = { value, key in
      .fireAndForget {
        XCTAssertEqual(key, "hasShownFirstLaunchOnboardingKey")
        XCTAssertEqual(value, true)
        isFirstLaunchOnboardingKeySet = true
      }
    }

    let store = TestStore(
      initialState: OnboardingState(presentationStyle: .help),
      reducer: onboardingReducer,
      environment: environment
    )

    store.send(.onAppear)

    self.mainQueue.advance(by: .seconds(4))
    store.receive(.delayedNextStep) {
      $0.step = .step2_FindWordsOnCube
    }

    store.send(.skipButtonTapped)

    store.receive(.delegate(.getStarted))

    XCTAssertEqual(isFirstLaunchOnboardingKeySet, true)
  }

  func testSkip_HasNotSeenOnboardingBefore() {
    var isFirstLaunchOnboardingKeySet = false

    var environment = OnboardingEnvironment.failing
    environment.audioPlayer = .noop
    environment.backgroundQueue = .immediate
    environment.dictionary.load = { _ in true }
    environment.mainQueue = self.mainQueue.eraseToAnyScheduler()
    environment.userDefaults.boolForKey = { key in
      XCTAssertEqual(key, "hasShownFirstLaunchOnboardingKey")
      return false
    }
    environment.userDefaults.setBool = { value, key in
      .fireAndForget {
        XCTAssertEqual(key, "hasShownFirstLaunchOnboardingKey")
        XCTAssertEqual(value, true)
        isFirstLaunchOnboardingKeySet = true
      }
    }

    let store = TestStore(
      initialState: OnboardingState(presentationStyle: .firstLaunch),
      reducer: onboardingReducer,
      environment: environment
    )

    store.send(.onAppear)

    self.mainQueue.advance(by: .seconds(4))
    store.receive(.delayedNextStep) {
      $0.step = .step2_FindWordsOnCube
    }

    store.send(.skipButtonTapped) {
      $0.alert = .init(
        title: .init("Skip tutorial?"),
        message: .init("""
          Are you sure you want to skip the tutorial? It only takes about a minute to complete.

          You can always view it again later in settings.
          """),
        primaryButton: .default(.init("Yes, skip"), send: .skipButtonTapped),
        secondaryButton: .default(.init("No, resume"), send: .resumeButtonTapped)
      )
    }

    store.send(.alert(.skipButtonTapped)) {
      $0.alert = nil
    }

    store.receive(.alert(.confirmSkipButtonTapped)) {
      $0.step = .step21_PlayAGameYourself
    }

    store.send(.getStartedButtonTapped)
    store.receive(.delegate(.getStarted))

    XCTAssertEqual(isFirstLaunchOnboardingKeySet, true)
  }
}

extension OnboardingEnvironment {
  static let failing = Self(
    audioPlayer: .failing,
    backgroundQueue: .failing("backgroundQueue"),
    dictionary: .failing,
    feedbackGenerator: .failing,
    lowPowerMode: .failing,
    mainQueue: .failing("mainQueue"),
    mainRunLoop: .failing,
    userDefaults: .failing
  )
}
