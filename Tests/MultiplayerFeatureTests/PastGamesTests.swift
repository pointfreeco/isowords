import ClientModels
import ComposableArchitecture
import ComposableGameCenter
import Dependencies
import Overture
import SharedModels
import TestHelpers
import XCTest

@testable import MultiplayerFeature

class PastGamesTests: XCTestCase {
  @MainActor
  func testLoadMatches() async {
    let store = withDependencies {
      $0.gameCenter.localPlayer.localPlayer = { .authenticated }
      $0.gameCenter.turnBasedMatch.loadMatches = { [match] }
    } operation: {
      TestStore(initialState: PastGames.State()) {
        PastGames()
      }
    }

    await store.mountTask?.value
    store.expect {
      $0.pastGames = [snap(pastGameState)]
    }
  }

  @MainActor
  func testOpenMatch() async {
    let store = withDependencies {
      $0.gameCenter.localPlayer.localPlayer = { .authenticated }
      $0.gameCenter.turnBasedMatch.loadMatches = { [match] }
      $0.gameCenter.turnBasedMatch.load = { _ in match }
    } operation: {
      TestStore(initialState: PastGames.State(pastGames: [pastGameState])) {
        PastGames()
      }
    }
    await store.mountTask?.value

    await store.send(.pastGames("id", .tappedRow))?.value
    await store.receive(key: PastGame.OpenMatch.self, value: .equals(match))
  }

  @MainActor
  func testRematch() async {
    let store = withDependencies {
      $0.gameCenter.localPlayer.localPlayer = { .authenticated }
      $0.gameCenter.turnBasedMatch.loadMatches = { [match] }
      $0.gameCenter.turnBasedMatch.rematch = { _ in match }
    } operation: {
      TestStore(initialState: PastGames.State(pastGames: [pastGameState])) {
        PastGames()
      }
    }
    await store.mountTask?.value

    await store.send(.pastGames("id", .rematchButtonTapped)) {
      $0.pastGames[0].isRematchRequestInFlight = true
    }?.value
    store.expect {
      $0.pastGames[0].isRematchRequestInFlight = false
    }
    await store.receive(key: PastGame.OpenMatch.self, value: .equals(match))
  }

  @MainActor
  func testRematch_Failure() async {
    struct RematchFailure: Error, Equatable {}

    let store = withDependencies {
      $0.gameCenter.localPlayer.localPlayer = { .authenticated }
      $0.gameCenter.turnBasedMatch.loadMatches = { [match] }
      $0.gameCenter.turnBasedMatch.rematch = { _ in throw RematchFailure() }
    } operation: {
      TestStore(initialState: PastGames.State(pastGames: [pastGameState])) {
        PastGames()
      }
    }
    await store.mountTask?.value

    await store.send(.pastGames("id", .rematchButtonTapped)) {
      $0.pastGames[0].isRematchRequestInFlight = true
    }?.value
    store.expect {
      $0.pastGames[0].isRematchRequestInFlight = false
      $0.pastGames[0].isRematchErrorAlertPresented = true
    }
  }
}

private let pastGameState = PastGame.State(
  challengeeDisplayName: "Blob Jr.",
  challengerDisplayName: "Blob",
  challengeeScore: 0,
  challengerScore: 1234,
  endDate: .mock,
  matchId: "id",
  opponentDisplayName: "Blob Jr."
)

private let match = TurnBasedMatch(
  creationDate: .mock,
  currentParticipant: .local,
  matchData: try! JSONEncoder().encode(
    TurnBasedMatchData(
      cubes: .mock,
      gameMode: .unlimited,
      language: .en,
      metadata: .init(
        lastOpenedAt: nil,
        playerIndexToId: [
          0: SharedModels.Player.blob.id,
          1: SharedModels.Player.blobJr.id,
        ]
      ),
      moves: [
        update(.highScoringMove) { $0.playerIndex = 0 },
        .mock,
        .playedWord(length: 10),
      ]
    )
  ),
  matchId: "id",
  participants: [.local, .remote],
  status: .ended
)
