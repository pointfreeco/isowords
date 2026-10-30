import ComposableArchitecture
import ConcurrencyExtras
import Dependencies
import XCTest

@testable import MultiplayerFeature

class MultiplayerFeatureTests: XCTestCase {
  @MainActor
  func testStartGame_GameCenterAuthenticated() async {
    let didPresentMatchmakerViewController = ActorIsolated(false)
    let store = withDependencies {
      $0.gameCenter.localPlayer.localPlayer = { .authenticated }
      $0.gameCenter.turnBasedMatchmakerViewController.present = { @Sendable _ in
        await didPresentMatchmakerViewController.setValue(true)
      }
    } operation: {
      TestStore(initialState: Multiplayer.State(hasPastGames: false)) {
        Multiplayer()
      }
    }

    await store.send(.startButtonTapped)?.value
    await didPresentMatchmakerViewController.withValue { XCTAssertTrue($0) }
  }

  @MainActor
  func testStartGame_GameCenterNotAuthenticated() async {
    let didPresentAuthentication = ActorIsolated(false)
    let store = withDependencies {
      $0.gameCenter.localPlayer.localPlayer = { .notAuthenticated }
      $0.gameCenter.localPlayer.presentAuthenticationViewController = {
        await didPresentAuthentication.setValue(true)
      }
    } operation: {
      TestStore(initialState: Multiplayer.State(hasPastGames: false)) {
        Multiplayer()
      }
    }

    await store.send(.startButtonTapped)?.value
    await didPresentAuthentication.withValue { XCTAssertTrue($0) }
  }

  @MainActor
  func testNavigateToPastGames() async {
    let store = withDependencies {
      $0.gameCenter.localPlayer.localPlayer = { .authenticated }
      $0.gameCenter.turnBasedMatch.loadMatches = { [] }
    } operation: {
      TestStore(initialState: Multiplayer.State(hasPastGames: true)) {
        Multiplayer()
      }
    }

    await store.send(.pastGamesButtonTapped) {
      $0.destination = .pastGames(.init(pastGames: []))
    }?.value
    store.modify {
      $0.destination = nil
    }
  }
}
