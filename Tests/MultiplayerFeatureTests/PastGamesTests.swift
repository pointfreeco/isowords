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
    var environment = PastGamesEnvironment.unimplemented
    environment.gameCenter.localPlayer.localPlayer = { .authenticated }
    environment.gameCenter.turnBasedMatch.loadMatches = { [match] }

    let store = TestStore(
      initialState: PastGamesState(),
      reducer: pastGamesReducer,
      environment: environment
    )

    await store.send(.task)

    await store.receive(.matchesResponse(.success([pastGameState]))) {
      $0.pastGames = [pastGameState]
    }
  }

  func testOpenMatch() async {
    var environment = PastGamesEnvironment.unimplemented
    environment.gameCenter.turnBasedMatch.load = { _ in match }

    let store = TestStore(
      initialState: PastGamesState(pastGames: [pastGameState]),
      reducer: pastGamesReducer,
      environment: environment
    )

    await store.send(.pastGame("id", .tappedRow))

    await store.receive(.pastGame("id", .matchResponse(.success(match))))

    await store.receive(.pastGame("id", .delegate(.openMatch(match))))
  }

  func testRematch() async {
    var environment = PastGamesEnvironment.unimplemented
    environment.gameCenter.turnBasedMatch.rematch = { _ in match }

    let store = TestStore(
      initialState: PastGamesState(pastGames: [pastGameState]),
      reducer: pastGamesReducer,
      environment: environment
    )

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

    var environment = PastGamesEnvironment.unimplemented
    environment.gameCenter.turnBasedMatch.rematch = { _ in throw RematchFailure() }

    let store = TestStore(
      initialState: PastGamesState(pastGames: [pastGameState]),
      reducer: pastGamesReducer,
      environment: environment
    )

    await store.send(.pastGame("id", .rematchButtonTapped)) {
      try XCTUnwrap(&$0.pastGames[id: "id"]) {
        $0.isRematchRequestInFlight = true
      }
    }

    await store.receive(.pastGame("id", .rematchResponse(.failure(RematchFailure())))) {
      try XCTUnwrap(&$0.pastGames[id: "id"]) {
        $0.isRematchRequestInFlight = false
        $0.alert = .init(
          title: .init("Error"),
          message: .init("We couldn’t start the rematch. Try again later."),
          dismissButton: .default(.init("Ok"), action: .send(.dismissAlert))
        )
      }
    }
  }
}

extension PastGamesEnvironment {
  static let unimplemented = Self(gameCenter: .unimplemented)
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
