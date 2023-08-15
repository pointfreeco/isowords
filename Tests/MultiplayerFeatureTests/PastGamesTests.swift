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
    let store = TestStore(
      initialState: PastGames.State()
    ) {
      PastGames()
    }

    store.dependencies.gameCenter.localPlayer.localPlayer = { .authenticated }
    store.dependencies.gameCenter.turnBasedMatch.loadMatches = { [match] }

    await store.send(.task)

    await store.receive(.matchesResponse(.success([pastGameState]))) {
      $0.pastGames = [pastGameState]
    }
  }

  func testOpenMatch() async {
    let store = TestStore(
      initialState: PastGames.State(pastGames: [pastGameState])
    ) {
      PastGames()
    }

    store.dependencies.gameCenter.turnBasedMatch.load = { _ in match }

    await store.send(.pastGame("id", .tappedRow))

    await store.receive(.pastGame("id", .matchResponse(.success(match))))

    await store.receive(.pastGame("id", .delegate(.openMatch(match))))
  }

  func testRematch() async {
    let store = TestStore(
      initialState: PastGames.State(pastGames: [pastGameState])
    ) {
      PastGames()
    }

    store.dependencies.gameCenter.turnBasedMatch.rematch = { _ in match }

    await store.send(.pastGame("id", .rematchButtonTapped)) {
      try XCTUnwrap(&$0.pastGames[id: "id"]) {
        $0.isRematchRequestInFlight = true
      }
    }

    await store.receive(.pastGame("id", .rematchResponse(.success(match)))) {
      try XCTUnwrap(&$0.pastGames[id: "id"]) {
        $0.isRematchRequestInFlight = false
      }
    }

    await store.receive(.pastGame("id", .delegate(.openMatch(match))))
  }

  func testRematch_Failure() async {
    struct RematchFailure: Error, Equatable {}

    let store = TestStore(
      initialState: PastGames.State(pastGames: [pastGameState])
    ) {
      PastGames()
    }

    store.dependencies.gameCenter.turnBasedMatch.rematch = { _ in throw RematchFailure() }

    await store.send(.pastGame("id", .rematchButtonTapped)) {
      try XCTUnwrap(&$0.pastGames[id: "id"]) {
        $0.isRematchRequestInFlight = true
      }
    }

    await store.receive(.pastGame("id", .rematchResponse(.failure(RematchFailure())))) {
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
