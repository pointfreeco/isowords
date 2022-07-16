import ComposableArchitecture
import XCTest

@testable import MultiplayerFeature

@MainActor
class MultiplayerFeatureTests: XCTestCase {
  func testStartGame_GameCenterAuthenticated() async {
    let didPresentMatchmakerViewController = SendableState(false)

    var environment = MultiplayerEnvironment.failing
    environment.gameCenter.localPlayer.localPlayerAsync = { .authenticated }
    environment.gameCenter.turnBasedMatchmakerViewController.presentAsync = { _ in
      await didPresentMatchmakerViewController.set(true)
    }

    let store = TestStore(
      initialState: MultiplayerState(hasPastGames: false),
      reducer: multiplayerReducer,
      environment: environment
    )

    await store.send(.startButtonTapped)
    await didPresentMatchmakerViewController.modify { XCTAssertNoDifference($0, true) }
  }

  func testStartGame_GameCenterNotAuthenticated() async {
    let didPresentAuthentication = SendableState(false)

    var environment = MultiplayerEnvironment.failing
    environment.gameCenter.localPlayer.localPlayerAsync = { .notAuthenticated }
    environment.gameCenter.localPlayer.presentAuthenticationViewControllerAsync = {
      await didPresentAuthentication.set(true)
    }

    let store = TestStore(
      initialState: MultiplayerState(hasPastGames: false),
      reducer: multiplayerReducer,
      environment: environment
    )

    await store.send(.startButtonTapped)
    await didPresentAuthentication.modify { XCTAssertNoDifference($0, true) }
  }

  func testNavigateToPastGames() async {
    let store = TestStore(
      initialState: MultiplayerState(hasPastGames: true),
      reducer: multiplayerReducer,
      environment: .failing
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
  static let failing = Self(
    backgroundQueue: .failing("backgroundQueue"),
    gameCenter: .failing,
    mainQueue: .failing("mainQueue")
  )
}
