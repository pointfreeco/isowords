import ComposableArchitecture
import XCTest

@testable import MultiplayerFeature

@MainActor
class MultiplayerFeatureTests: XCTestCase {
  func testStartGame_GameCenterAuthenticated() async {
    var didPresentMatchmakerViewController = false

    var environment = MultiplayerEnvironment.failing
    environment.gameCenter.localPlayer.localPlayer = { .authenticated }
    environment.gameCenter.turnBasedMatchmakerViewController.present = { _ in
      .fireAndForget {
        didPresentMatchmakerViewController = true
      }
    }

    let store = TestStore(
      initialState: MultiplayerState(hasPastGames: false),
      reducer: multiplayerReducer,
      environment: environment
    )

    await store.send(.startButtonTapped)

    XCTAssertNoDifference(didPresentMatchmakerViewController, true)
  }

  func testStartGame_GameCenterNotAuthenticated() async {
    var didPresentAuthentication = false

    var environment = MultiplayerEnvironment.failing
    environment.gameCenter.localPlayer.localPlayer = { .notAuthenticated }
    environment.gameCenter.localPlayer.presentAuthenticationViewController = .fireAndForget {
      didPresentAuthentication = true
    }

    let store = TestStore(
      initialState: MultiplayerState(hasPastGames: false),
      reducer: multiplayerReducer,
      environment: environment
    )

    await store.send(.startButtonTapped)

    XCTAssertNoDifference(didPresentAuthentication, true)
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
