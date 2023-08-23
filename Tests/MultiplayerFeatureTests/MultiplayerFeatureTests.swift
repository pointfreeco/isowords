import ComposableArchitecture
import XCTest

@testable import MultiplayerFeature

@MainActor
class MultiplayerFeatureTests: XCTestCase {
  func testStartGame_GameCenterAuthenticated() async {
    let didPresentMatchmakerViewController = ActorIsolated(false)
    let store = TestStore(initialState: Multiplayer.State(hasPastGames: false)) {
      Multiplayer()
    } withDependencies: {
      $0.gameCenter.localPlayer.localPlayer = { .authenticated }
      $0.gameCenter.turnBasedMatchmakerViewController.present = { @Sendable _ in
        await didPresentMatchmakerViewController.setValue(true)
      }
    }

    await store.send(.startButtonTapped)
    await didPresentMatchmakerViewController.withValue { XCTAssertTrue($0) }
  }

  func testStartGame_GameCenterNotAuthenticated() async {
    let didPresentAuthentication = ActorIsolated(false)
    let store = TestStore(
      initialState: Multiplayer.State(hasPastGames: false)
    ) {
      Multiplayer()
    } withDependencies: {
      $0.gameCenter.localPlayer.localPlayer = { .notAuthenticated }
      $0.gameCenter.localPlayer.presentAuthenticationViewController = {
        await didPresentAuthentication.setValue(true)
      }
    }

    await store.send(.startButtonTapped)
    await didPresentAuthentication.withValue { XCTAssertTrue($0) }
  }

  func testNavigateToPastGames() async {
    let store = TestStore(
      initialState: Multiplayer.State(hasPastGames: true)
    ) {
      Multiplayer()
    }

    await store.send(.pastGamesButtonTapped) {
      $0.destination = .pastGames(.init(pastGames: []))
    }
    await store.send(.destination(.dismiss)) {
      $0.destination = nil
    }
  }
}
