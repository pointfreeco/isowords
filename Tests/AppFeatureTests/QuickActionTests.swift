import ComposableArchitecture
import XCTest

@testable import AppFeature

final class QuickActionTests: XCTestCase {
  func testDailyChallengeQuickAction() {
    let store = TestStore(
      initialState: .init(),
      reducer: appReducer,
      environment: .didFinishLaunching
    )

    store.send(.appDelegate(.didFinishLaunching))
    store.send(.appDelegate(.scene(.quickAction(type: "dailyChallenge"))))
    store.receive(.home(.setNavigation(tag: .dailyChallenge))) {
      $0.home.route = .dailyChallenge(.init())
    }
  }

  func testUnknownQuickAction() {
    let store = TestStore(
      initialState: .init(),
      reducer: appReducer,
      environment: .didFinishLaunching
    )

    store.send(.appDelegate(.didFinishLaunching))
    store.send(.appDelegate(.scene(.quickAction(type: "unrecognizedQuickAction")))) // Expecting a no-op.
  }
}
