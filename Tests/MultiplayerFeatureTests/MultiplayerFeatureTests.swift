import ComposableArchitecture
import XCTest

@testable import MultiplayerFeature

@MainActor
class MultiplayerFeatureTests: XCTestCase {
  func testStartGame_GameCenterAuthenticated() async {
    let didPresentMatchmakerViewController = ActorIsolated(false)

    var environment = MultiplayerEnvironment.unimplemented
    environment.gameCenter.localPlayer.localPlayer = { .authenticated }
    environment.gameCenter.turnBasedMatchmakerViewController.present = { @Sendable _ in
      await didPresentMatchmakerViewController.setValue(true)
    }

    let store = TestStore(
      initialState: MultiplayerState(hasPastGames: false),
      reducer: multiplayerReducer,
      environment: environment
    )

    await store.send(.startButtonTapped)
    await didPresentMatchmakerViewController.withValue { XCTAssertNoDifference($0, true) }
  }

  func testStartGame_GameCenterNotAuthenticated() async {
    let didPresentAuthentication = ActorIsolated(false)

    var environment = MultiplayerEnvironment.unimplemented
    environment.gameCenter.localPlayer.localPlayer = { .notAuthenticated }
    environment.gameCenter.localPlayer.presentAuthenticationViewController = {
      await didPresentAuthentication.setValue(true)
    }

    let store = TestStore(
      initialState: MultiplayerState(hasPastGames: false),
      reducer: multiplayerReducer,
      environment: environment
    )

    await store.send(.startButtonTapped)
    await didPresentAuthentication.withValue { XCTAssertNoDifference($0, true) }
  }

  func testNavigateToPastGames() async {
    let store = TestStore(
      initialState: MultiplayerState(hasPastGames: true),
      reducer: multiplayerReducer,
      environment: .unimplemented
    )

    await store.send(.setNavigation(tag: .pastGames)) {
      $0.route = .pastGames(.init(pastGames: []))
    }
    await store.send(.setNavigation(tag: nil)) {
      $0.route = nil
    }
  }
}

extension MultiplayerEnvironment {
  static let unimplemented = Self(
    backgroundQueue: .unimplemented("backgroundQueue"),
    gameCenter: .unimplemented,
    mainQueue: .unimplemented("mainQueue")
  )
}
