import ClientModels
import ComposableArchitecture
import ComposableGameCenter
import Overture
import SharedModels
import TestHelpers
import XCTest

@testable import MultiplayerFeature

class PastGamesTests: XCTestCase {
  func testLoadMatches() {
    var environment = PastGamesEnvironment.failing
    environment.backgroundQueue = .immediate
    environment.gameCenter.localPlayer.localPlayer = { .authenticated }
    environment.gameCenter.turnBasedMatch.loadMatches = { .init(value: [match]) }
    environment.mainQueue = .immediate

    let store = TestStore(
      initialState: PastGamesState(),
      reducer: pastGamesReducer,
      environment: environment
    )

    store.send(.onAppear)

    store.receive(.matchesResponse(.success([pastGameState]))) {
      $0.pastGames = [pastGameState]
    }
  }

  func testOpenMatch() {
    var environment = PastGamesEnvironment.failing
    environment.gameCenter.turnBasedMatch.load = { _ in .init(value: match) }
    environment.mainQueue = .immediate

    let store = TestStore(
      initialState: PastGamesState(pastGames: [pastGameState]),
      reducer: pastGamesReducer,
      environment: environment
    )

    store.send(.pastGame("id", .tappedRow))

    store.receive(.pastGame("id", .matchResponse(.success(match))))

    store.receive(.pastGame("id", .delegate(.openMatch(match))))
  }

  func testRematch() {
    var environment = PastGamesEnvironment.failing
    environment.mainQueue = .immediate
    environment.gameCenter.turnBasedMatch.rematch = { _ in .init(value: match) }

    let store = TestStore(
      initialState: PastGamesState(pastGames: [pastGameState]),
      reducer: pastGamesReducer,
      environment: environment
    )

    store.send(.pastGame("id", .rematchButtonTapped)) {
      try XCTUnwrap(&$0.pastGames[id: "id"]) {
        $0.isRematchRequestInFlight = true
      }
    }

    store.receive(.pastGame("id", .rematchResponse(.success(match)))) {
      try XCTUnwrap(&$0.pastGames[id: "id"]) {
        $0.isRematchRequestInFlight = false
      }
    }

    store.receive(.pastGame("id", .delegate(.openMatch(match))))
  }

  func testRematch_Failure() {
    struct RematchFailure: Error, Equatable {}

    var environment = PastGamesEnvironment.failing
    environment.mainQueue = .immediate
    environment.gameCenter.turnBasedMatch.rematch = { _ in .init(error: RematchFailure()) }

    let store = TestStore(
      initialState: PastGamesState(pastGames: [pastGameState]),
      reducer: pastGamesReducer,
      environment: environment
    )

    store.send(.pastGame("id", .rematchButtonTapped)) {
      try XCTUnwrap(&$0.pastGames[id: "id"]) {
        $0.isRematchRequestInFlight = true
      }
    }

    store.receive(.pastGame("id", .rematchResponse(.failure(RematchFailure() as NSError)))) {
      try XCTUnwrap(&$0.pastGames[id: "id"]) {
        $0.isRematchRequestInFlight = false
        $0.alert = .init(
          title: .init("Error"),
          message: .init("We couldn’t start the rematch. Try again later."),
          primaryButton: .default(.init("Ok"), send: .dismissAlert),
          secondaryButton: nil
        )
      }
    }
  }
}

extension PastGamesEnvironment {
  static let failing = Self(
    backgroundQueue: .failing("backgroundQueue"),
    gameCenter: .failing,
    mainQueue: .failing("mainQueue")
  )
}

private let pastGameState = PastGameState(
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
        ],
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
