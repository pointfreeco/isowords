import ComposableArchitecture
import ConcurrencyExtras
import CustomDump
import Dependencies
import SharedModels
import XCTest

@testable import OnboardingFeature

class OnboardingFeatureTests: XCTestCase {
  let clock = TestClock<Duration>()
  let now = Date(timeIntervalSinceReferenceDate: 0)

  @MainActor
  func testBasics_FirstLaunch() async {
    let isFirstLaunchOnboardingKeySet = ActorIsolated(false)
    
    let store = withDependencies {
      $0.audioPlayer = .noop
      $0.dictionary.load = { _ in true }
      $0.dictionary.contains = { word, _ in
        ["GAME", "CUBES", "REMOVE", "WORD"].contains(word)
      }
      $0.feedbackGenerator = .noop
      $0.userDefaults.setBool = { value, key in
        expectNoDifference(key, "hasShownFirstLaunchOnboardingKey")
        expectNoDifference(value, true)
        await isFirstLaunchOnboardingKeySet.setValue(true)
      }
    } operation: {
      TestStore(initialState: Onboarding.State(presentationStyle: .firstLaunch)) {
        Onboarding()
          .environment(\.continuousClock, self.clock)
      }
    }

    await self.clock.advance(by: .seconds(4))
    store.expect {
      $0.step = .step2_FindWordsOnCube
    }

    store.send(.nextButtonTapped) {
      $0.step = .step3_ConnectLettersTouching
    }

    store.send(.nextButtonTapped) {
      $0.step = .step4_FindGame
    }

    // Find and submit "GAME"
    store.send(.cubeScene(.tap(.began, .init(index: .init(x: .one, y: .two, z: .two), side: .left))))
    await store.receive(\.game.tap) {
      $0.game.optimisticallySelectedFace = .init(index: .init(x: .one, y: .two, z: .two), side: .left)
      $0.game.selectedWord.append(.init(index: .init(x: .one, y: .two, z: .two), side: .left))
    }
    store.send(.cubeScene(.tap(.began, .init(index: .init(x: .two, y: .two, z: .two), side: .left))))
    await store.receive(\.game.tap) {
      $0.game.optimisticallySelectedFace = .init(index: .init(x: .two, y: .two, z: .two), side: .left)
      $0.game.selectedWord.append(.init(index: .init(x: .two, y: .two, z: .two), side: .left))
    }
    store.send(.cubeScene(.tap(.began, .init(index: .init(x: .two, y: .two, z: .two), side: .right))))
    await store.receive(\.game.tap) {
      $0.game.optimisticallySelectedFace = .init(index: .init(x: .two, y: .two, z: .two), side: .right)
      $0.game.selectedWord.append(.init(index: .init(x: .two, y: .two, z: .two), side: .right))
    }
    store.send(.cubeScene(.tap(.began, .init(index: .init(x: .two, y: .two, z: .one), side: .right))))
    await store.receive(\.game.tap) {
      $0.step = .step5_SubmitGame
      $0.game.optimisticallySelectedFace = .init(index: .init(x: .two, y: .two, z: .one), side: .right)
      $0.game.selectedWord.append(.init(index: .init(x: .two, y: .two, z: .one), side: .right))
      $0.game.selectedWordIsValid = true
    }
    store.send(.submitButtonTapped) {
      $0.step = .step6_Congrats
    }
    await store.receive(\.game.submitButtonTapped) {
      $0.game.cubes.1.2.2.left.useCount += 1
      $0.game.cubes.2.2.2.left.useCount += 1
      $0.game.cubes.2.2.2.right.useCount += 1
      $0.game.cubes.2.2.1.right.useCount += 1
      $0.game.moves.append(
        .init(
          playedAt: self.now,
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
    }

    // Wait a moment to automatically go to the next step
    await self.clock.advance(by: .seconds(2))
    store.expect {
      $0.step = .step7_BiggerCube
    }

    store.send(.nextButtonTapped) {
      $0.step = .step8_FindCubes
    }

    // Find and submit the word "CUBES"
    store.send(.cubeScene(.tap(.began, .init(index: .init(x: .one, y: .two, z: .two), side: .top))))
    await store.receive(\.game.tap) {
      $0.game.optimisticallySelectedFace = .init(index: .init(x: .one, y: .two, z: .two), side: .top)
      $0.game.selectedWord.append(.init(index: .init(x: .one, y: .two, z: .two), side: .top))
    }
    store.send(.cubeScene(.tap(.began, .init(index: .init(x: .one, y: .two, z: .one), side: .top))))
    await store.receive(\.game.tap) {
      $0.game.optimisticallySelectedFace = .init(index: .init(x: .one, y: .two, z: .one), side: .top)
      $0.game.selectedWord.append(.init(index: .init(x: .one, y: .two, z: .one), side: .top))
    }
    store.send(.cubeScene(.tap(.began, .init(index: .init(x: .two, y: .two, z: .two), side: .top))))
    await store.receive(\.game.tap) {
      $0.game.optimisticallySelectedFace = .init(index: .init(x: .two, y: .two, z: .two), side: .top)
      $0.game.selectedWord.append(.init(index: .init(x: .two, y: .two, z: .two), side: .top))
    }
    store.send(.cubeScene(.tap(.began, .init(index: .init(x: .two, y: .two, z: .one), side: .right))))
    await store.receive(\.game.tap) {
      $0.game.optimisticallySelectedFace = .init(index: .init(x: .two, y: .two, z: .one), side: .right)
      $0.game.selectedWord.append(.init(index: .init(x: .two, y: .two, z: .one), side: .right))
    }
    store.send(.cubeScene(.tap(.began, .init(index: .init(x: .two, y: .two, z: .one), side: .top))))
    await store.receive(\.game.tap) {
      $0.game.optimisticallySelectedFace = .init(index: .init(x: .two, y: .two, z: .one), side: .top)
      $0.game.selectedWord.append(.init(index: .init(x: .two, y: .two, z: .one), side: .top))
      $0.game.selectedWordIsValid = true
    }
    store.send(.submitButtonTapped) {
      $0.step = .step9_Congrats
    }
    await store.receive(\.game.submitButtonTapped) {
      $0.game.cubes.1.2.2.top.useCount += 1
      $0.game.cubes.1.2.1.top.useCount += 1
      $0.game.cubes.2.2.2.top.useCount += 1
      $0.game.cubes.2.2.1.right.useCount += 1
      $0.game.cubes.2.2.1.top.useCount += 1
      $0.game.moves.append(
        .init(
          playedAt: self.now,
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
    }

    // Wait a moment to automatically go to the next step
    await self.clock.advance(by: .seconds(2))
    store.expect {
      $0.step = .step10_CubeDisappear
    }

    store.send(.nextButtonTapped) {
      $0.step = .step11_FindRemove
    }

    // Find and submit the word "REMOVE"
    store.send(.cubeScene(.tap(.began, .init(index: .init(x: .one, y: .one, z: .two), side: .left))))
    await store.receive(\.game.tap) {
      $0.game.optimisticallySelectedFace = .init(index: .init(x: .one, y: .one, z: .two), side: .left)
      $0.game.selectedWord.append(.init(index: .init(x: .one, y: .one, z: .two), side: .left))
    }
    store.send(.cubeScene(.tap(.began, .init(index: .init(x: .two, y: .one, z: .two), side: .left))))
    await store.receive(\.game.tap) {
      $0.game.optimisticallySelectedFace = .init(index: .init(x: .two, y: .one, z: .two), side: .left)
      $0.game.selectedWord.append(.init(index: .init(x: .two, y: .one, z: .two), side: .left))
    }
    store.send(.cubeScene(.tap(.began, .init(index: .init(x: .two, y: .two, z: .two), side: .right))))
    await store.receive(\.game.tap) {
      $0.game.optimisticallySelectedFace = .init(index: .init(x: .two, y: .two, z: .two), side: .right)
      $0.game.selectedWord.append(.init(index: .init(x: .two, y: .two, z: .two), side: .right))
    }
    store.send(.cubeScene(.tap(.began, .init(index: .init(x: .two, y: .one, z: .two), side: .right))))
    await store.receive(\.game.tap) {
      $0.game.optimisticallySelectedFace = .init(index: .init(x: .two, y: .one, z: .two), side: .right)
      $0.game.selectedWord.append(.init(index: .init(x: .two, y: .one, z: .two), side: .right))
    }
    store.send(.cubeScene(.tap(.began, .init(index: .init(x: .two, y: .one, z: .one), side: .right))))
    await store.receive(\.game.tap) {
      $0.game.optimisticallySelectedFace = .init(index: .init(x: .two, y: .one, z: .one), side: .right)
      $0.game.selectedWord.append(.init(index: .init(x: .two, y: .one, z: .one), side: .right))
    }
    store.send(.cubeScene(.tap(.began, .init(index: .init(x: .two, y: .two, z: .one), side: .right))))
    await store.receive(\.game.tap) {
      $0.game.cubeStartedShakingAt = self.now
      $0.game.optimisticallySelectedFace = .init(index: .init(x: .two, y: .two, z: .one), side: .right)
      $0.game.selectedWord.append(.init(index: .init(x: .two, y: .two, z: .one), side: .right))
      $0.game.selectedWordIsValid = true
      $0.step = .step12_CubeIsShaking
    }
    store.send(.submitButtonTapped) {
      $0.step = .step13_Congrats
    }
    await store.receive(\.game.submitButtonTapped) {
      $0.game.cubeStartedShakingAt = nil
      $0.game.cubes.1.1.2.left.useCount += 1
      $0.game.cubes.2.1.2.left.useCount += 1
      $0.game.cubes.2.2.2.right.useCount += 1
      $0.game.cubes.2.1.2.right.useCount += 1
      $0.game.cubes.2.1.1.right.useCount += 1
      $0.game.cubes.2.2.1.right.useCount += 1
      $0.game.moves.append(
        .init(
          playedAt: self.now,
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
    }

    await self.clock.advance(by: .seconds(3))
    store.expect {
      $0.step = .step14_LettersRevealed
    }

    store.send(.nextButtonTapped) {
      $0.step = .step15_FullCube
    }
    store.send(.nextButtonTapped) {
      $0.step = .step16_FindAnyWord
    }

    // Find the word "WORD"
    store.send(.cubeScene(.tap(.began, .init(index: .init(x: .zero, y: .zero, z: .two), side: .left))))
    await store.receive(\.game.tap) {
      $0.game.optimisticallySelectedFace = .init(index: .init(x: .zero, y: .zero, z: .two), side: .left)
      $0.game.selectedWord.append(.init(index: .init(x: .zero, y: .zero, z: .two), side: .left))
    }
    store.send(.cubeScene(.tap(.began, .init(index: .init(x: .one, y: .zero, z: .two), side: .left))))
    await store.receive(\.game.tap) {
      $0.game.optimisticallySelectedFace = .init(index: .init(x: .one, y: .zero, z: .two), side: .left)
      $0.game.selectedWord.append(.init(index: .init(x: .one, y: .zero, z: .two), side: .left))
    }
    store.send(.cubeScene(.tap(.began, .init(index: .init(x: .two, y: .zero, z: .two), side: .left))))
    await store.receive(\.game.tap) {
      $0.game.optimisticallySelectedFace = .init(index: .init(x: .two, y: .zero, z: .two), side: .left)
      $0.game.selectedWord.append(.init(index: .init(x: .two, y: .zero, z: .two), side: .left))
    }
    store.send(.cubeScene(.tap(.began, .init(index: .init(x: .two, y: .zero, z: .two), side: .right))))
    await store.receive(\.game.tap) {
      $0.game.optimisticallySelectedFace = .init(index: .init(x: .two, y: .zero, z: .two), side: .right)
      $0.game.selectedWord.append(.init(index: .init(x: .two, y: .zero, z: .two), side: .right))
      $0.game.selectedWordIsValid = true
    }
    store.send(.submitButtonTapped) {
      $0.step = .step17_Congrats
    }
    await store.receive(\.game.submitButtonTapped) {
      $0.game.cubes.0.0.2.left.useCount += 1
      $0.game.cubes.1.0.2.left.useCount += 1
      $0.game.cubes.2.0.2.left.useCount += 1
      $0.game.cubes.2.0.2.right.useCount += 1
      $0.game.moves.append(
        .init(
          playedAt: self.now,
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
    }

    await self.clock.advance(by: .seconds(2))
    store.expect {
      $0.step = .step18_OneLastThing
    }

    store.send(.nextButtonTapped) {
      $0.step = .step19_DoubleTapToRemove
    }

    store.send(.cubeScene(.doubleTap(index: .init(x: .two, y: .two, z: .two)))) {
      $0.step = .step20_Congrats
    }
    await store.receive(\.game.confirmRemoveCube) {
      $0.game.cubes.2.2.2.wasRemoved = true
      $0.game.moves.append(
        .init(
          playedAt: self.now,
          playerIndex: nil,
          reactions: nil,
          score: 0,
          type: .removedCube(.init(x: .two, y: .two, z: .two))
        )
      )
      $0.step = .step20_Congrats
    }

    await self.clock.advance(by: .seconds(2))
    store.expect {
      $0.step = .step21_PlayAGameYourself
    }

    store.send(.getStartedButtonTapped)
    await store.receive(key: Onboarding.GetStarted.self)

    await isFirstLaunchOnboardingKeySet.withValue { XCTAssert($0) }
  }

  @MainActor
  func testSkip_HasSeenOnboardingBefore() async {
    let isFirstLaunchOnboardingKeySet = ActorIsolated(false)

    let store = withDependencies {
      $0.audioPlayer = .noop
      $0.dictionary.load = { _ in true }
      $0.userDefaults.boolForKey = { key in
        expectNoDifference(key, "hasShownFirstLaunchOnboardingKey")
        return true
      }
      $0.userDefaults.setBool = { value, key in
        expectNoDifference(key, "hasShownFirstLaunchOnboardingKey")
        expectNoDifference(value, true)
        await isFirstLaunchOnboardingKeySet.setValue(true)
      }
    } operation: {
      TestStore(initialState: Onboarding.State(presentationStyle: .help)) {
        Onboarding()
          .environment(\.continuousClock, self.clock)
      }
    }

    await self.clock.advance(by: .seconds(4))
    store.expect {
      $0.step = .step2_FindWordsOnCube
    }

    store.send(.skipButtonTapped)

    await store.receive(key: Onboarding.GetStarted.self)

    await isFirstLaunchOnboardingKeySet.withValue { XCTAssert($0) }
  }

  @MainActor
  func testSkip_HasNotSeenOnboardingBefore() async {
    let isFirstLaunchOnboardingKeySet = ActorIsolated(false)

    let store = withDependencies {
      $0.audioPlayer = .noop
      $0.dictionary.load = { _ in true }
      $0.userDefaults.boolForKey = { key in
        expectNoDifference(key, "hasShownFirstLaunchOnboardingKey")
        return false
      }
      $0.userDefaults.setBool = { value, key in
        expectNoDifference(key, "hasShownFirstLaunchOnboardingKey")
        expectNoDifference(value, true)
        await isFirstLaunchOnboardingKeySet.setValue(true)
      }
    } operation: {
      TestStore(initialState: Onboarding.State(presentationStyle: .firstLaunch)) {
        Onboarding()
          .environment(\.continuousClock, self.clock)
      }
    }

    await self.clock.advance(by: .seconds(4))
    store.expect {
      $0.step = .step2_FindWordsOnCube
    }

    store.send(.skipButtonTapped) {
      $0.alert = snap(Onboarding.Alert.State())
    }

    store.send(.alert(.skipButtonTapped)) {
      $0.alert = nil
      $0.step = .step21_PlayAGameYourself
    }

    store.send(.getStartedButtonTapped)
    await store.receive(key: Onboarding.GetStarted.self)

    await isFirstLaunchOnboardingKeySet.withValue { XCTAssert($0) }
  }
}
