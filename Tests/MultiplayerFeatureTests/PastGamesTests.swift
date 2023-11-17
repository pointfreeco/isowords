import ClientModels
import ComposableArchitecture
import ComposableGameCenter
import Overture
import SharedModels
import TestHelpers
import XCTest

@testable import MultiplayerFeature

@MainActor
class PastGamesTests: XCTestCase {
  func testLoadMatches() async {
    let store = TestStore(initialState: PastGames.State()) {
      PastGames()
    } withDependencies: {
      $0.gameCenter.localPlayer.localPlayer = { .authenticated }
      $0.gameCenter.turnBasedMatch.loadMatches = { [match] }
    }

    await store.send(.task)
    await store.receive(\.matchesResponse.success) {
      $0.pastGames = [pastGameState]
    }
  }

  func testOpenMatch() async {
    let store = TestStore(initialState: PastGames.State(pastGames: [pastGameState])) {
      PastGames()
    } withDependencies: {
      $0.gameCenter.turnBasedMatch.load = { _ in match }
    }

    await store.send(.pastGames(.element(id: "id", action: .tappedRow)))
    await store.receive(\.pastGames[id: "id"].matchResponse.success)
    await store.receive(\.pastGames[id: "id"].delegate.openMatch)
  }

  func testRematch() async {
    let store = TestStore(initialState: PastGames.State(pastGames: [pastGameState])) {
      PastGames()
    } withDependencies: {
      $0.gameCenter.turnBasedMatch.rematch = { _ in match }
    }

    await store.send(.pastGames(.element(id: "id", action: .rematchButtonTapped))) {
      try XCTUnwrap(&$0.pastGames[id: "id"]) {
        $0.isRematchRequestInFlight = true
      }
    }

    await store.receive(\.pastGames[id: "id"].rematchResponse.success) {
      try XCTUnwrap(&$0.pastGames[id: "id"]) {
        $0.isRematchRequestInFlight = false
      }
    }

    await store.receive(\.pastGames[id: "id"].delegate.openMatch)
  }

  func testRematch_Failure() async {
    struct RematchFailure: Error, Equatable {}

    let store = TestStore(initialState: PastGames.State(pastGames: [pastGameState])) {
      PastGames()
    } withDependencies: {
      $0.gameCenter.turnBasedMatch.rematch = { _ in throw RematchFailure() }
    }

    await store.send(.pastGames(.element(id: "id", action: .rematchButtonTapped))) {
      try XCTUnwrap(&$0.pastGames[id: "id"]) {
        $0.isRematchRequestInFlight = true
      }
    }

    await store.receive(\.pastGames[id: "id"].rematchResponse.failure) {
      try XCTUnwrap(&$0.pastGames[id: "id"]) {
        $0.isRematchRequestInFlight = false
        $0.alert = .init {
          TextState("Error")
        } actions: {
          ButtonState { TextState("Ok") }
        } message: {
          TextState("We couldn’t start the rematch. Try again later.")
        }
      }
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
        .playedWord(length: 10)
      ]
    )
  ),
  matchId: "id",
  participants: [.local, .remote],
  status: .ended
)
