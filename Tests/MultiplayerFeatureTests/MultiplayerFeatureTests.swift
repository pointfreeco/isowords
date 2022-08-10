import ComposableArchitecture
import XCTest

@testable import MultiplayerFeature

@MainActor
class MultiplayerFeatureTests: XCTestCase {
  func testStartGame_GameCenterAuthenticated() async {
    let store = TestStore(
      initialState: Multiplayer.State(hasPastGames: false),
      reducer: Multiplayer()
    )

    let didPresentMatchmakerViewController = ActorIsolated(false)
    store.dependencies.gameCenter.localPlayer.localPlayer = { .authenticated }
    store.dependencies.gameCenter.turnBasedMatchmakerViewController.present = { @Sendable _ in
      await didPresentMatchmakerViewController.setValue(true)
    }

    await store.send(.startButtonTapped)
    await didPresentMatchmakerViewController.withValue { XCTAssertTrue($0) }
  }

  func testStartGame_GameCenterNotAuthenticated() async {
    let store = TestStore(
      initialState: Multiplayer.State(hasPastGames: false),
      reducer: Multiplayer()
    )

    let didPresentAuthentication = ActorIsolated(false)
    store.dependencies.gameCenter.localPlayer.localPlayer = { .notAuthenticated }
    store.dependencies.gameCenter.localPlayer.presentAuthenticationViewController = {
      await didPresentAuthentication.setValue(true)
    }

    await store.send(.startButtonTapped)
    await didPresentAuthentication.withValue { XCTAssertTrue($0) }
  }

  func testNavigateToPastGames() async {
    let store = TestStore(
      initialState: Multiplayer.State(hasPastGames: true),
      reducer: Multiplayer()
    )

    await store.send(.pastGames(.present(PastGames.State()))) {
      $0.pastGames = PastGames.State()
    }
    await store.send(.pastGames(.dismiss)) {
      $0.pastGames = nil
    }
  }
}
