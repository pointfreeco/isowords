import BottomMenu
import ClientModels
import Combine
import ComposableArchitecture
import ComposableGameCenter
import DictionaryClient
import GameFeature
import GameKit
import GameOverFeature
import HomeKit
import MultiplayerFeature
import Overture
import SettingsFeature
import SharedModels
import SoloFeature
import TestHelpers
import XCTest

@testable import AppFeature
@testable import ComposableGameCenter
@testable import HomeFeature

class TurnBasedTests: XCTestCase {
  let backgroundQueue = DispatchQueue.testScheduler
  let mainQueue = DispatchQueue.testScheduler
  let mainRunLoop = RunLoop.testScheduler

  func testNewGame() {
    var didEndTurnWithRequest: TurnBasedMatchClient.EndTurnRequest?
    var didSaveCurrentTurn = false
    let listener = PassthroughSubject<LocalPlayerClient.ListenerEvent, Never>()

    let match = update(TurnBasedMatch.inProgress) {
      $0.currentParticipant?.player = .remote
    }

    let store = TestStore(
      initialState: .init(
        home: .init(route: .multiplayer(.init(hasPastGames: false)))
      ),
      reducer: appReducer,
      environment: update(.didFinishLaunching) {
        $0.apiClient.override(route: .dailyChallenge(.today(language: .en)), withResponse: .none)
        $0.apiClient
          .override(route: .leaderboard(.weekInReview(language: .en)), withResponse: .none)
        $0.apiClient.authenticate = { _ in .init(value: .mock) }
        $0.apiClient.currentPlayer = { nil }
        $0.audioPlayer.play = { _ in .none }
        $0.backgroundQueue = self.backgroundQueue.eraseToAnyScheduler()
        $0.deviceId.id = { .deviceId }
        $0.dictionary.contains = { word, _ in word == "CAB" }
        $0.dictionary.randomCubes = { _ in .mock }
        $0.gameCenter.localPlayer.authenticate = .init(value: nil)
        $0.gameCenter.localPlayer.listener = listener.eraseToEffect()
        $0.gameCenter.localPlayer.localPlayer = { .mock }
        $0.gameCenter.turnBasedMatch.endTurn = {
          didEndTurnWithRequest = $0
          return .none
        }
        $0.gameCenter.turnBasedMatch.load = { _ in .init(value: match) }
        $0.gameCenter.turnBasedMatch.loadMatches = { .init(value: []) }
        $0.gameCenter.turnBasedMatch.saveCurrentTurn = { _, _ in
          didSaveCurrentTurn = true
          return .none
        }
        $0.gameCenter.turnBasedMatchmakerViewController.dismiss = .none
        $0.gameCenter.turnBasedMatchmakerViewController._present = { _ in .none }
        $0.feedbackGenerator = .noop
        $0.serverConfig.config = { .init() }
        $0.serverConfig.refresh = { .init(value: .init()) }
        $0.timeZone = { .newYork }
      }
    )

    store.send(.appDelegate(.didFinishLaunching))
    store.send(.home(.onAppear))

    store.receive(.home(.authenticationResponse(.mock)))

    self.backgroundQueue.advance()
    store.receive(.home(.binding(.set(\.hasPastTurnBasedGames, false))))
    store.receive(.home(.matchesLoaded(.success([]))))

    store.send(.home(.multiplayer(.startButtonTapped)))

    listener.send(.turnBased(.receivedTurnEventForMatch(.new, didBecomeActive: true)))

    store.receive(
      .gameCenter(.listener(.turnBased(.receivedTurnEventForMatch(.new, didBecomeActive: true))))
    ) {
      $0.game = GameState(
        inProgressGame: InProgressGame(
          cubes: .mock,
          gameContext: .turnBased(.init(localPlayer: .mock, match: .new, metadata: .init())),
          gameMode: .unlimited,
          gameStartTime: self.mainRunLoop.now.date,
          moves: [],
          secondsPlayed: 0
        )
      )
    }

    self.backgroundQueue.advance()
    store.receive(.home(.binding(.set(\.hasPastTurnBasedGames, false))))
    store.receive(.home(.matchesLoaded(.success([]))))

    XCTAssert(didSaveCurrentTurn)

    let index = LatticePoint(x: .two, y: .two, z: .two)
    let C = IndexedCubeFace(index: index, side: .top)
    let A = IndexedCubeFace(index: index, side: .left)
    let B = IndexedCubeFace(index: index, side: .right)

    store.send(.currentGame(.game(.tap(.began, C)))) {
      try XCTUnwrap(&$0.game) {
        $0.optimisticallySelectedFace = C
        $0.selectedWord = [C]
      }
    }
    store.send(.currentGame(.game(.tap(.ended, C)))) {
      try XCTUnwrap(&$0.game) {
        $0.optimisticallySelectedFace = nil
      }
    }
    store.send(.currentGame(.game(.tap(.began, A)))) {
      try XCTUnwrap(&$0.game) {
        $0.optimisticallySelectedFace = A
        $0.selectedWord = [C, A]
      }
    }
    store.send(.currentGame(.game(.tap(.ended, A)))) {
      try XCTUnwrap(&$0.game) {
        $0.optimisticallySelectedFace = nil
      }
    }
    store.send(.currentGame(.game(.tap(.began, B)))) {
      try XCTUnwrap(&$0.game) {
        $0.optimisticallySelectedFace = B
        $0.selectedWord = [C, A, B]
        $0.selectedWordIsValid = true
      }
    }
    store.send(.currentGame(.game(.tap(.ended, B)))) {
      try XCTUnwrap(&$0.game) {
        $0.optimisticallySelectedFace = nil
      }
    }
    store.send(.currentGame(.game(.submitButtonTapped(.angel)))) {
      try XCTUnwrap(&$0.game) {
        $0.moves = [
          .init(
            playedAt: self.mainRunLoop.now.date,
            playerIndex: 0,
            reactions: [0: .angel],
            score: 27,
            type: .playedWord($0.selectedWord)
          )
        ]
        $0.selectedWord = []
        $0.selectedWordIsValid = false
        $0.cubes[index].left.useCount = 1
        $0.cubes[index].right.useCount = 1
        $0.cubes[index].top.useCount = 1
      }

      XCTAssertEqual(
        didEndTurnWithRequest,
        .init(
          for: match.matchId,
          matchData: Data(
            turnBasedMatchData: TurnBasedMatchData(
              context: try XCTUnwrap($0.currentGame.game?.turnBasedContext),
              gameState: try XCTUnwrap($0.game),
              playerId: nil
            )
          ),
          message: "Blob played CAB! (+27 😇)"
        )
      )
    }

    store.receive(.currentGame(.game(.gameCenter(.turnBasedMatchResponse(.success(match)))))) {
      try XCTUnwrap(&$0.game) {
        $0.turnBasedContext = .init(localPlayer: .mock, match: match, metadata: .init())
      }
    }

    listener.send(completion: .finished)
  }

  func testResumeGame() {
    let listener = PassthroughSubject<LocalPlayerClient.ListenerEvent, Never>()
    let store = TestStore(
      initialState: .init(),
      reducer: appReducer,
      environment: update(.didFinishLaunching) {
        $0.apiClient.authenticate = { _ in .init(value: .mock) }
        $0.apiClient.currentPlayer = { nil }
        $0.apiClient.override(route: .dailyChallenge(.today(language: .en)), withResponse: .none)
        $0.apiClient
          .override(route: .leaderboard(.weekInReview(language: .en)), withResponse: .none)
        $0.backgroundQueue = self.backgroundQueue.eraseToAnyScheduler()
        $0.deviceId.id = { .deviceId }
        $0.gameCenter.localPlayer.authenticate = .init(value: nil)
        $0.gameCenter.localPlayer.listener = listener.eraseToEffect()
        $0.gameCenter.localPlayer.localPlayer = { .mock }
        $0.gameCenter.turnBasedMatch.loadMatches = { .init(value: []) }
        $0.gameCenter.turnBasedMatchmakerViewController.dismiss = .none
        $0.serverConfig.config = { .init() }
        $0.timeZone = { .newYork }
      }
    )

    store.send(.appDelegate(.didFinishLaunching))
    store.send(.home(.onAppear))
    store.receive(.home(.authenticationResponse(.mock)))

    self.backgroundQueue.advance()
    store.receive(.home(.binding(.set(\.hasPastTurnBasedGames, false))))
    store.receive(.home(.matchesLoaded(.success([]))))

    listener.send(.turnBased(.receivedTurnEventForMatch(.inProgress, didBecomeActive: true)))

    store.receive(
      .gameCenter(
        .listener(
          .turnBased(
            .receivedTurnEventForMatch(.inProgress, didBecomeActive: true)
          )
        )
      )
    ) {
      $0.game = update(
        GameState(
          inProgressGame: InProgressGame(
            cubes: .mock,
            gameContext: .turnBased(
              .init(localPlayer: .mock, match: .inProgress, metadata: .init())
            ),
            gameMode: .unlimited,
            gameStartTime: .mock,
            moves: [],
            secondsPlayed: 0
          )
        )
      ) { $0.gameCurrentTime = self.mainRunLoop.now.date }
    }

    self.backgroundQueue.advance()
    store.receive(.home(.binding(.set(\.hasPastTurnBasedGames, false))))
    store.receive(.home(.matchesLoaded(.success([]))))

    listener.send(completion: .finished)
  }

  func testResumeForfeitedGame() {
    let listener = PassthroughSubject<LocalPlayerClient.ListenerEvent, Never>()
    let store = TestStore(
      initialState: .init(),
      reducer: appReducer,
      environment: update(.didFinishLaunching) {
        $0.apiClient.authenticate = { _ in .init(value: .mock) }
        $0.apiClient.currentPlayer = { nil }
        $0.apiClient.override(route: .dailyChallenge(.today(language: .en)), withResponse: .none)
        $0.apiClient
          .override(route: .leaderboard(.weekInReview(language: .en)), withResponse: .none)
        $0.backgroundQueue = self.backgroundQueue.eraseToAnyScheduler()
        $0.deviceId.id = { .deviceId }
        $0.gameCenter.localPlayer.authenticate = .init(value: nil)
        $0.gameCenter.localPlayer.listener = listener.eraseToEffect()
        $0.gameCenter.localPlayer.localPlayer = { .mock }
        $0.gameCenter.turnBasedMatch.loadMatches = { .init(value: []) }
        $0.gameCenter.turnBasedMatchmakerViewController.dismiss = .none
        $0.serverConfig.config = { .init() }
        $0.timeZone = { .newYork }
      }
    )

    store.send(.appDelegate(.didFinishLaunching))
    store.send(.home(.onAppear))
    store.receive(.home(.authenticationResponse(.mock)))

    self.backgroundQueue.advance()
    store.receive(.home(.binding(.set(\.hasPastTurnBasedGames, false))))
    store.receive(.home(.matchesLoaded(.success([]))))

    listener.send(.turnBased(.receivedTurnEventForMatch(.forfeited, didBecomeActive: true)))

    store.receive(
      .gameCenter(
        .listener(
          .turnBased(
            .receivedTurnEventForMatch(.forfeited, didBecomeActive: true)
          )
        )
      )
    ) {
      var gameState = GameState(
        inProgressGame: InProgressGame(
          cubes: .mock,
          gameContext: .turnBased(
            .init(localPlayer: .mock, match: .forfeited, metadata: .init())
          ),
          gameMode: .unlimited,
          gameStartTime: .mock,
          moves: [],
          secondsPlayed: 0
        )
      )
      gameState.gameCurrentTime = self.mainRunLoop.now.date
      gameState.gameOver = GameOverState(
        completedGame: CompletedGame(gameState: gameState),
        isDemo: false,
        turnBasedContext: .init(localPlayer: .mock, match: .forfeited, metadata: .init())
      )
      $0.game = gameState
    }

    self.backgroundQueue.advance()
    store.receive(.home(.binding(.set(\.hasPastTurnBasedGames, false))))
    store.receive(.home(.matchesLoaded(.success([]))))

    listener.send(completion: .finished)
  }

  func testRemovingCubes() {
    var didEndTurnWithRequest: TurnBasedMatchClient.EndTurnRequest?
    let match = update(TurnBasedMatch.inProgress) {
      $0.participants = [.local, .remote]
    }

    let environment = update(AppEnvironment.failing) {
      $0.apiClient.currentPlayer = { nil }
      $0.audioPlayer.play = { _ in .none }
      $0.gameCenter.localPlayer.localPlayer = { .mock }
      $0.gameCenter.turnBasedMatch.load = { _ in .init(value: .inProgress) }
      $0.gameCenter.turnBasedMatch.saveCurrentTurn = { _, _ in .init(value: ()) }
      $0.gameCenter.turnBasedMatch.endTurn = {
        didEndTurnWithRequest = $0
        return .init(value: ())
      }
      $0.mainRunLoop = self.mainRunLoop.eraseToAnyScheduler()
    }

    let store = TestStore(
      initialState: AppState(
        game: GameState(
          cubes: update(.mock) {
            $0.0.0.0 = .init(
              left: .init(letter: "A", side: .left),
              right: .init(letter: "A", side: .right),
              top: .init(letter: "A", side: .top)
            )
            $0.0.0.1 = .init(
              left: .init(letter: "A", side: .left),
              right: .init(letter: "A", side: .right),
              top: .init(letter: "A", side: .top)
            )
            $0.0.0.2 = .init(
              left: .init(letter: "A", side: .left),
              right: .init(letter: "A", side: .right),
              top: .init(letter: "A", side: .top)
            )
          },
          gameContext: .turnBased(.init(localPlayer: .mock, match: match, metadata: .init())),
          gameCurrentTime: self.mainRunLoop.now.date,
          gameMode: .unlimited,
          gameStartTime: .mock,
          secondsPlayed: 0
        )
      ),
      reducer: appReducer,
      environment: environment
    )

    let nextTurn = update(TurnBasedMatch.inProgress) {
      $0.currentParticipant = .init(
        lastTurnDate: .mock,
        matchOutcome: .none,
        player: .remote,
        status: .active,
        timeoutDate: nil
      )
    }

    store.send(.currentGame(.game(.doubleTap(index: .zero)))) {
      try XCTUnwrap(&$0.game) {
        $0.bottomMenu = .removeCube(index: .zero, state: $0, isTurnEndingRemoval: false)
      }
    }
    store.send(.currentGame(.game(.confirmRemoveCube(.zero)))) {
      try XCTUnwrap(&$0.game) {
        $0.bottomMenu = nil
        $0.cubes.0.0.0.wasRemoved = true
        $0.moves.append(
          .init(
            playedAt: self.mainRunLoop.now.date,
            playerIndex: 0,
            reactions: nil,
            score: 0,
            type: .removedCube(.zero)
          )
        )
      }
    }
    store.receive(.currentGame(.game(.gameCenter(.turnBasedMatchResponse(.success(.inProgress))))))
    store.send(.currentGame(.game(.doubleTap(index: .init(x: .zero, y: .zero, z: .one))))) {
      try XCTUnwrap(&$0.game) {
        $0.bottomMenu = .removeCube(
          index: .init(x: .zero, y: .zero, z: .one),
          state: $0,
          isTurnEndingRemoval: true
        )
      }
    }

    store.environment.gameCenter.turnBasedMatch.load = { _ in .init(value: nextTurn) }

    store.send(.currentGame(.game(.confirmRemoveCube(.init(x: .zero, y: .zero, z: .one))))) {
      try XCTUnwrap(&$0.game) {
        $0.moves.append(
          .init(
            playedAt: self.mainRunLoop.now.date,
            playerIndex: 0,
            reactions: nil,
            score: 0,
            type: .removedCube(.init(x: .zero, y: .zero, z: .one))
          )
        )
        $0.cubes.0.0.1.wasRemoved = true
        $0.bottomMenu = nil
      }
    }
    store.receive(.currentGame(.game(.gameCenter(.turnBasedMatchResponse(.success(nextTurn)))))) {
      try XCTUnwrap(&$0.game) {
        try XCTUnwrap(&$0.turnBasedContext) {
          $0.match = nextTurn
        }
      }
    }
    store.send(.currentGame(.game(.doubleTap(index: .init(x: .zero, y: .zero, z: .two))))) {
      XCTAssertEqual(
        didEndTurnWithRequest,
        .init(
          for: match.matchId,
          matchData: Data(
            turnBasedMatchData: TurnBasedMatchData(
              context: try XCTUnwrap($0.game?.turnBasedContext),
              gameState: try XCTUnwrap($0.game),
              playerId: nil
            )
          ),
          message: "Blob removed cubes!"
        )
      )
    }
  }

  func testRematch() {
    let localParticipant = TurnBasedParticipant.local
    let match = update(TurnBasedMatch.inProgress) {
      $0.currentParticipant = localParticipant
      $0.participants = [localParticipant, .remote]
    }
    var didRematchWithId: TurnBasedMatch.Id?

    let environment = update(AppEnvironment.failing) {
      $0.apiClient.currentPlayer = { nil }
      $0.dictionary.randomCubes = { _ in .mock }
      $0.fileClient.load = { _ in .none }
      $0.gameCenter.localPlayer.localPlayer = {
        update(.authenticated) { $0.player = localParticipant.player! }
      }
      $0.gameCenter.turnBasedMatch.loadMatches = { .none }
      $0.gameCenter.turnBasedMatch.rematch = {
        didRematchWithId = $0
        return .init(value: .new)
      }
      $0.gameCenter.turnBasedMatch.saveCurrentTurn = { _, _ in .none }
      $0.gameCenter.turnBasedMatchmakerViewController.dismiss = .none
      $0.mainQueue = self.mainQueue.eraseToAnyScheduler()
      $0.mainRunLoop = self.mainRunLoop.eraseToAnyScheduler()
    }

    let store = TestStore(
      initialState: AppState(
        game: update(
          GameState(
            cubes: .mock,
            gameContext: .turnBased(.init(localPlayer: .mock, match: match, metadata: .init())),
            gameCurrentTime: .mock,
            gameMode: .unlimited,
            gameStartTime: .mock
          )
        ) {
          $0.gameOver = GameOverState(
            completedGame: CompletedGame(gameState: $0),
            isDemo: false
          )
        }
      ),
      reducer: appReducer,
      environment: environment
    )

    store.send(.currentGame(.game(.gameOver(.rematchButtonTapped)))) {
      $0.game = nil
    }
    XCTAssertEqual(didRematchWithId, match.matchId)
    self.mainQueue.advance()

    store.receive(.gameCenter(.rematchResponse(.success(.new)))) {
      $0.currentGame = GameFeatureState(
        game: GameState(
          cubes: .mock,
          gameContext: .turnBased(.init(localPlayer: .mock, match: .new, metadata: .init())),
          gameCurrentTime: self.mainRunLoop.now.date,
          gameMode: .unlimited,
          gameStartTime: self.mainRunLoop.now.date
        ),
        settings: $0.home.settings
      )
    }
  }

  func testGameCenterNotification_ShowsRecentTurn() {
    let localParticipant = TurnBasedParticipant.local
    let remoteParticipant = update(TurnBasedParticipant.remote) {
      $0.lastTurnDate = self.mainRunLoop.now.date - 10
    }
    let match = update(TurnBasedMatch.inProgress) {
      $0.currentParticipant = localParticipant
      $0.participants = [
        localParticipant,
        remoteParticipant,
      ]
      $0.matchData = .init(
        turnBasedMatchData: TurnBasedMatchData(
          cubes: .mock,
          gameMode: .unlimited,
          language: .en,
          metadata: .init(),
          moves: [
            .init(
              playedAt: remoteParticipant.lastTurnDate!,
              playerIndex: 1,
              reactions: nil,
              score: 10,
              type: .playedWord(
                [
                  .init(index: .init(x: .two, y: .two, z: .two), side: .left),
                  .init(index: .init(x: .two, y: .two, z: .two), side: .right),
                  .init(index: .init(x: .two, y: .two, z: .two), side: .top),
                ]
              )
            )
          ]
        )
      )
      $0.message = "Blob played ABC!"
    }

    var notificationBannerRequest: GameCenterClient.NotificationBannerRequest?
    let environment = update(AppEnvironment.failing) {
      $0.gameCenter.localPlayer.localPlayer = { .authenticated }
      $0.gameCenter.showNotificationBanner = {
        notificationBannerRequest = $0
        return .none
      }
      $0.gameCenter.turnBasedMatch.loadMatches = { .none }
      $0.mainQueue = self.mainQueue.eraseToAnyScheduler()
      $0.mainRunLoop = self.mainRunLoop.eraseToAnyScheduler()
    }

    let store = TestStore(
      initialState: AppState(),
      reducer: appReducer,
      environment: environment
    )

    store.send(
      .gameCenter(
        .listener(.turnBased(.receivedTurnEventForMatch(match, didBecomeActive: false)))
      )
    )

    self.mainQueue.advance()
    XCTAssertEqual(
      notificationBannerRequest,
      GameCenterClient.NotificationBannerRequest(
        title: "Blob played ABC!",
        message: nil
      )
    )
  }

  func testGameCenterNotification_DoesNotShow() {
    let localParticipant = TurnBasedParticipant.local
    let remoteParticipant = update(TurnBasedParticipant.remote) {
      $0.lastTurnDate = self.mainRunLoop.now.date - 10
    }
    let match = update(TurnBasedMatch.inProgress) {
      $0.currentParticipant = remoteParticipant
      $0.participants = [
        localParticipant,
        remoteParticipant,
      ]
      $0.matchData = .init(
        turnBasedMatchData: TurnBasedMatchData(
          cubes: .mock,
          gameMode: .unlimited,
          language: .en,
          metadata: .init(),
          moves: [
            .init(
              playedAt: remoteParticipant.lastTurnDate!,
              playerIndex: 1,
              reactions: nil,
              score: 0,
              type: .removedCube(.init(x: .two, y: .two, z: .two))
            )
          ]
        )
      )
      $0.message = "Let's play!"
    }

    let environment = update(AppEnvironment.failing) {
      $0.gameCenter.localPlayer.localPlayer = { .authenticated }
      $0.gameCenter.turnBasedMatch.loadMatches = { .none }
      $0.mainQueue = self.mainQueue.eraseToAnyScheduler()
      $0.mainRunLoop = self.mainRunLoop.eraseToAnyScheduler()
    }

    let store = TestStore(
      initialState: AppState(),
      reducer: appReducer,
      environment: environment
    )

    store.send(
      .gameCenter(
        .listener(.turnBased(.receivedTurnEventForMatch(match, didBecomeActive: false)))
      )
    )
    self.mainQueue.run()
  }
}
