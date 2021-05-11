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
  let backgroundQueue = DispatchQueue.test
  let mainQueue = DispatchQueue.test

  func testNewGame() throws {
    var didEndTurnWithRequest: TurnBasedMatchClient.EndTurnRequest?
    var didSaveCurrentTurn = false
    let listener = PassthroughSubject<LocalPlayerClient.ListenerEvent, Never>()

    var environment = AppEnvironment.didFinishLaunching
    environment.apiClient.override(route: .dailyChallenge(.today(language: .en)), withResponse: .none)
    environment.apiClient
      .override(route: .leaderboard(.weekInReview(language: .en)), withResponse: .none)
    environment.apiClient.authenticate = { _ in .init(value: .mock) }
    let currentPlayer = CurrentPlayerEnvelope.mock
    environment.apiClient.currentPlayer = { currentPlayer }
    environment.audioPlayer.loop = { _ in .none }
    environment.audioPlayer.play = { _ in .none }
    environment.audioPlayer.stop = { _ in .none }
    environment.backgroundQueue = self.backgroundQueue.eraseToAnyScheduler()
    environment.build.number = { 42 }
    environment.database.playedGamesCount = { _ in .none }
    environment.deviceId.id = { .deviceId }
    environment.dictionary.contains = { word, _ in word == "CAB" }
    environment.dictionary.randomCubes = { _ in .mock }
    environment.feedbackGenerator = .noop
    environment.gameCenter.localPlayer.authenticate = .init(value: nil)
    environment.gameCenter.localPlayer.listener = listener.eraseToEffect()
    environment.gameCenter.localPlayer.localPlayer = { .mock }
    environment.gameCenter.turnBasedMatch.endTurn = {
      didEndTurnWithRequest = $0
      return .none
    }
    environment.gameCenter.turnBasedMatch.loadMatches = { .init(value: []) }
    environment.gameCenter.turnBasedMatch.saveCurrentTurn = { _, _ in
      didSaveCurrentTurn = true
      return .none
    }
    environment.gameCenter.turnBasedMatchmakerViewController.dismiss = .none
    environment.gameCenter.turnBasedMatchmakerViewController.present = { _ in .none }
    environment.lowPowerMode.start = .none
    environment.mainQueue = self.mainQueue.eraseToAnyScheduler()
    environment.serverConfig.config = { .init() }
    environment.serverConfig.refresh = { .init(value: .init()) }
    environment.timeZone = { .newYork }

    let store = TestStore(
      initialState: .init(
        home: .init(route: .multiplayer(.init(hasPastGames: false)))
      ),
      reducer: appReducer,
      environment: environment
    )

    store.send(.appDelegate(.didFinishLaunching))
    store.send(.home(.onAppear))

    self.mainQueue.advance()

    store.receive(.home(.authenticationResponse(.mock)))
    store.receive(.home(.serverConfigResponse(.init()))) {
      $0.home.hasChangelog = true
    }

    self.backgroundQueue.advance()
    self.mainQueue.advance()

    store.receive(.home(.binding(.set(\.hasPastTurnBasedGames, false))))
    store.receive(.home(.matchesLoaded(.success([]))))

    store.send(.home(.multiplayer(.startButtonTapped)))

    let newMatch = update(TurnBasedMatch.new) { $0.creationDate = environment.$mainQueue.now }

    listener.send(.turnBased(.receivedTurnEventForMatch(newMatch, didBecomeActive: true)))

    let initialGameState = GameState(
      inProgressGame: InProgressGame(
        cubes: .mock,
        gameContext: .turnBased(
          .init(
            localPlayer: .mock,
            match: newMatch,
            metadata: .init(lastOpenedAt: nil, playerIndexToId: [:])
          )
        ),
        gameMode: .unlimited,
        gameStartTime: newMatch.creationDate,
        moves: [],
        secondsPlayed: 0
      )
    )
    store.receive(
      .gameCenter(.listener(.turnBased(.receivedTurnEventForMatch(newMatch, didBecomeActive: true))))
    ) {
      $0.game = initialGameState
      try XCTUnwrap(&$0.game) {
        try XCTUnwrap(&$0.turnBasedContext) {
          $0.metadata.lastOpenedAt = store.environment.$mainQueue.now
        }
      }
    }
    store.environment.userDefaults.override(integer: 0, forKey: "multiplayerOpensCount")
    store.environment.userDefaults.setInteger = { int, key in
      XCTAssertEqual(int, 1)
      XCTAssertEqual(key, "multiplayerOpensCount")
      return .none
    }
    store.send(.currentGame(.game(.onAppear)))

    self.mainQueue.advance(by: 0.5)

    store.receive(.currentGame(.game(.matchesLoaded(.success([])))))
    store.receive(.currentGame(.game(.gameLoaded))) {
      try XCTUnwrap(&$0.game) {
        $0.isGameLoaded = true
      }
    }

    self.backgroundQueue.advance()
    self.mainQueue.advance()
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

    let updatedGameState = try update(initialGameState) {
      $0.isGameLoaded = true
      $0.moves = [
        .init(
          playedAt: environment.$mainQueue.now,
          playerIndex: 0,
          reactions: [0: .angel],
          score: 27,
          type: .playedWord([C, A, B])
        )
      ]
      $0.selectedWord = []
      $0.selectedWordIsValid = false
      $0.cubes[index].left.useCount = 1
      $0.cubes[index].right.useCount = 1
      $0.cubes[index].top.useCount = 1
      try XCTUnwrap(&$0.turnBasedContext) {
        $0.metadata.lastOpenedAt = store.environment.$mainQueue.now
      }
    }
    let updatedMatch = update(newMatch) {
      $0.currentParticipant = .remote
      $0.matchData = Data(
        turnBasedMatchData: TurnBasedMatchData(
          context: TurnBasedContext(
            localPlayer: .mock,
            match: newMatch,
            metadata: .init(
              lastOpenedAt: store.environment.$mainQueue.now,
              playerIndexToId: [0: currentPlayer.player.id]
            )
          ),
          gameState: updatedGameState,
          playerId: currentPlayer.player.id
        )
      )
    }
    store.environment.gameCenter.turnBasedMatch.load = { _ in
      .init(value: updatedMatch)
    }

    store.send(.currentGame(.game(.submitButtonTapped(reaction: .angel)))) {
      $0.game = updatedGameState
      $0.game?.gameCurrentTime = environment.$mainQueue.now

      XCTAssertEqual(
        didEndTurnWithRequest,
        .init(
          for: newMatch.matchId,
          matchData: Data(
            turnBasedMatchData: TurnBasedMatchData(
              context: try XCTUnwrap($0.currentGame.game?.turnBasedContext),
              gameState: try XCTUnwrap($0.game),
              playerId: currentPlayer.player.id
            )
          ),
          message: "Blob played CAB! (+27 😇)"
        )
      )
    }

    store.receive(
      .currentGame(.game(.gameCenter(.turnBasedMatchResponse(.success(updatedMatch)))))
    ) {
      try XCTUnwrap(&$0.game) {
        $0.turnBasedContext = .init(
          localPlayer: .mock,
          match: updatedMatch,
          metadata: .init(
            lastOpenedAt: store.environment.$mainQueue.now,
            playerIndexToId: [0: currentPlayer.player.id]
          )
        )
      }
    }

    store.send(.currentGame(.onDisappear))
    listener.send(completion: .finished)
  }

  func testResumeGame() {
    let listener = PassthroughSubject<LocalPlayerClient.ListenerEvent, Never>()

    var environment = AppEnvironment.didFinishLaunching
    environment.apiClient.authenticate = { _ in .init(value: .mock) }
    environment.apiClient.currentPlayer = { nil }
    environment.apiClient.override(route: .dailyChallenge(.today(language: .en)), withResponse: .none)
    environment.apiClient
        .override(route: .leaderboard(.weekInReview(language: .en)), withResponse: .none)
    environment.backgroundQueue = self.backgroundQueue.eraseToAnyScheduler()
    environment.deviceId.id = { .deviceId }
    environment.gameCenter.localPlayer.authenticate = .init(value: nil)
    environment.gameCenter.localPlayer.listener = listener.eraseToEffect()
    environment.gameCenter.localPlayer.localPlayer = { .mock }
    environment.gameCenter.turnBasedMatch.saveCurrentTurn = { _, _ in .none }
    environment.gameCenter.turnBasedMatch.loadMatches = { .init(value: []) }
    environment.gameCenter.turnBasedMatchmakerViewController.dismiss = .none
    environment.serverConfig.config = { .init() }
    environment.timeZone = { .newYork }

    let store = TestStore(
      initialState: .init(),
      reducer: appReducer,
      environment: environment
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
              .init(
                localPlayer: .mock,
                match: .inProgress,
                metadata: .init(lastOpenedAt: nil, playerIndexToId: [:])
              )
            ),
            gameMode: .unlimited,
            gameStartTime: .mock,
            moves: [],
            secondsPlayed: 0
          )
        )
      ) { $0.gameCurrentTime = environment.$mainQueue.now }
    }

    self.backgroundQueue.advance()
    store.receive(.home(.binding(.set(\.hasPastTurnBasedGames, false))))
    store.receive(.home(.matchesLoaded(.success([]))))

    listener.send(completion: .finished)
  }

  func testResumeForfeitedGame() {
    let listener = PassthroughSubject<LocalPlayerClient.ListenerEvent, Never>()

    var environment = AppEnvironment.didFinishLaunching
    environment.apiClient.authenticate = { _ in .init(value: .mock) }
    environment.apiClient.currentPlayer = { nil }
    environment.apiClient.override(route: .dailyChallenge(.today(language: .en)), withResponse: .none)
    environment.apiClient
      .override(route: .leaderboard(.weekInReview(language: .en)), withResponse: .none)
    environment.backgroundQueue = self.backgroundQueue.eraseToAnyScheduler()
    environment.deviceId.id = { .deviceId }
    environment.gameCenter.localPlayer.authenticate = .init(value: nil)
    environment.gameCenter.localPlayer.listener = listener.eraseToEffect()
    environment.gameCenter.localPlayer.localPlayer = { .mock }
    environment.gameCenter.turnBasedMatch.loadMatches = { .init(value: []) }
    environment.gameCenter.turnBasedMatchmakerViewController.dismiss = .none
    environment.serverConfig.config = { .init() }
    environment.timeZone = { .newYork }

    let store = TestStore(
      initialState: .init(),
      reducer: appReducer,
      environment: environment
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
            .init(
              localPlayer: .mock,
              match: .forfeited,
              metadata: .init(lastOpenedAt: nil, playerIndexToId: [:])
            )
          ),
          gameMode: .unlimited,
          gameStartTime: .mock,
          moves: [],
          secondsPlayed: 0
        )
      )
      gameState.gameCurrentTime = environment.$mainQueue.now
      gameState.gameOver = GameOverState(
        completedGame: CompletedGame(gameState: gameState),
        isDemo: false,
        turnBasedContext: .init(
          localPlayer: .mock,
          match: .forfeited,
          metadata: .init(lastOpenedAt: nil, playerIndexToId: [:])
        )
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

    let environment = update(AppEnvironment.failing) {
      $0.apiClient.currentPlayer = { nil }
      $0.audioPlayer.play = { _ in .none }
      $0.gameCenter.localPlayer.localPlayer = { .mock }
      $0.gameCenter.turnBasedMatch.saveCurrentTurn = { _, _ in .init(value: ()) }
      $0.gameCenter.turnBasedMatch.endTurn = {
        didEndTurnWithRequest = $0
        return .init(value: ())
      }
      $0.mainQueue = self.mainQueue.eraseToAnyScheduler()
    }

    let match = update(TurnBasedMatch.inProgress) {
      $0.creationDate = environment.$mainQueue.now.addingTimeInterval(-60*5)
      $0.participants = [.local, .remote]
    }

    let initialGameState = GameState(
      cubes: .mock,
      gameContext: .turnBased(
        .init(
          localPlayer: .mock,
          match: match,
          metadata: .init(lastOpenedAt: nil, playerIndexToId: [:])
        )
      ),
      gameCurrentTime: environment.$mainQueue.now,
      gameMode: .unlimited,
      gameStartTime: match.creationDate,
      secondsPlayed: 0
    )
    let store = TestStore(
      initialState: AppState(game: initialGameState),
      reducer: appReducer,
      environment: environment
    )

    store.send(.currentGame(.game(.doubleTap(index: .zero)))) {
      try XCTUnwrap(&$0.game) {
        $0.bottomMenu = .removeCube(index: .zero, state: $0, isTurnEndingRemoval: false)
      }
    }

    var updatedGameState = update(initialGameState) {
      $0.bottomMenu = nil
      $0.cubes.0.0.0.wasRemoved = true
      $0.moves.append(
        .init(
          playedAt: environment.$mainQueue.now,
          playerIndex: 0,
          reactions: nil,
          score: 0,
          type: .removedCube(.zero)
        )
      )
    }
    var updatedMatch = update(match) {
      $0.matchData = Data(
        turnBasedMatchData: TurnBasedMatchData(
          context: TurnBasedContext(
            localPlayer: .mock,
            match: match,
            metadata: .init(lastOpenedAt: nil, playerIndexToId: [:])
          ),
          gameState: updatedGameState,
          playerId: nil
        )
      )
    }
    store.environment.gameCenter.turnBasedMatch.load = { _ in .init(value: updatedMatch) }

    store.send(.currentGame(.game(.confirmRemoveCube(.zero)))) {
      $0.game = updatedGameState
    }
    store.receive(
      .currentGame(.game(.gameCenter(.turnBasedMatchResponse(.success(updatedMatch)))))
    ) {
      try XCTUnwrap(&$0.game) {
        try XCTUnwrap(&$0.turnBasedContext) {
          $0.match = updatedMatch
        }
      }
    }
    store.send(.currentGame(.game(.doubleTap(index: .init(x: .zero, y: .zero, z: .one))))) {
      try XCTUnwrap(&$0.game) {
        $0.bottomMenu = .removeCube(
          index: .init(x: .zero, y: .zero, z: .one),
          state: $0,
          isTurnEndingRemoval: true
        )
      }
    }

    updatedGameState = update(updatedGameState) {
      $0.moves.append(
        .init(
          playedAt: environment.$mainQueue.now,
          playerIndex: 0,
          reactions: nil,
          score: 0,
          type: .removedCube(.init(x: .zero, y: .zero, z: .one))
        )
      )
      $0.turnBasedContext?.match = updatedMatch
      $0.cubes.0.0.1.wasRemoved = true
      $0.bottomMenu = nil
    }
    updatedMatch = update(updatedMatch) {
      $0.currentParticipant = .remote
      $0.matchData = Data(
        turnBasedMatchData: TurnBasedMatchData(
          context: TurnBasedContext(
            localPlayer: .mock,
            match: updatedMatch,
            metadata: .init(lastOpenedAt: nil, playerIndexToId: [:])
          ),
          gameState: updatedGameState,
          playerId: nil
        )
      )
    }
    store.environment.gameCenter.turnBasedMatch.load = { _ in .init(value: updatedMatch) }

    store.send(.currentGame(.game(.confirmRemoveCube(.init(x: .zero, y: .zero, z: .one))))) {
      $0.game = updatedGameState
    }
    store.receive(.currentGame(.game(.gameCenter(.turnBasedMatchResponse(.success(updatedMatch)))))) {
      try XCTUnwrap(&$0.game) {
        try XCTUnwrap(&$0.turnBasedContext) {
          $0.match = updatedMatch
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
    var didRematchWithId: TurnBasedMatch.Id?

    var environment = AppEnvironment.failing
    environment.mainQueue = self.mainQueue.eraseToAnyScheduler()
    environment.apiClient.currentPlayer = { nil }
    environment.dictionary.randomCubes = { _ in .mock }
    environment.fileClient.load = { _ in .none }
    environment.gameCenter.localPlayer.localPlayer = {
      update(.authenticated) { $0.player = localParticipant.player! }
    }
    environment.gameCenter.turnBasedMatch.loadMatches = { .none }
    let newMatch = update(TurnBasedMatch.new) { $0.creationDate = environment.$mainQueue.now }
    environment.gameCenter.turnBasedMatch.rematch = {
      didRematchWithId = $0
      return .init(value: newMatch)
    }
    environment.gameCenter.turnBasedMatch.saveCurrentTurn = { _, _ in .none }
    environment.gameCenter.turnBasedMatchmakerViewController.dismiss = .none

    let match = update(TurnBasedMatch.inProgress) {
      $0.currentParticipant = localParticipant
      $0.creationDate = environment.$mainQueue.now.addingTimeInterval(-60*5)
      $0.participants = [localParticipant, .remote]
    }

    let store = TestStore(
      initialState: AppState(
        game: update(
          GameState(
            cubes: .mock,
            gameContext: .turnBased(
              .init(
                localPlayer: .mock,
                match: match,
                metadata: .init(lastOpenedAt: nil, playerIndexToId: [:])
              )
            ),
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

    store.receive(.gameCenter(.rematchResponse(.success(newMatch)))) {
      $0.currentGame = GameFeatureState(
        game: GameState(
          cubes: .mock,
          gameContext: .turnBased(
            .init(
              localPlayer: .mock,
              match: newMatch,
              metadata: .init(lastOpenedAt: environment.$mainQueue.now, playerIndexToId: [:])
            )
          ),
          gameCurrentTime: environment.$mainQueue.now,
          gameMode: .unlimited,
          gameStartTime: newMatch.creationDate
        ),
        settings: $0.home.settings
      )
    }
  }

  func testGameCenterNotification_ShowsRecentTurn() {
    var notificationBannerRequest: GameCenterClient.NotificationBannerRequest?
    let environment = update(AppEnvironment.failing) {
      $0.gameCenter.localPlayer.localPlayer = { .authenticated }
      $0.gameCenter.showNotificationBanner = {
        notificationBannerRequest = $0
        return .none
      }
      $0.gameCenter.turnBasedMatch.loadMatches = { .none }
      $0.mainQueue = self.mainQueue.eraseToAnyScheduler()
    }

    let store = TestStore(
      initialState: AppState(),
      reducer: appReducer,
      environment: environment
    )

    let localParticipant = TurnBasedParticipant.local
    let remoteParticipant = update(TurnBasedParticipant.remote) {
      $0.lastTurnDate = environment.$mainQueue.now - 10
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
          metadata: .init(lastOpenedAt: nil, playerIndexToId: [:]),
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
    let environment = update(AppEnvironment.failing) {
      $0.gameCenter.localPlayer.localPlayer = { .authenticated }
      $0.gameCenter.turnBasedMatch.loadMatches = { .none }
      $0.mainQueue = self.mainQueue.eraseToAnyScheduler()
    }

    let store = TestStore(
      initialState: AppState(),
      reducer: appReducer,
      environment: environment
    )

    let localParticipant = TurnBasedParticipant.local
    let remoteParticipant = update(TurnBasedParticipant.remote) {
      $0.lastTurnDate = environment.$mainQueue.now - 10
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
          metadata: .init(lastOpenedAt: nil, playerIndexToId: [:]),
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

    store.send(
      .gameCenter(
        .listener(.turnBased(.receivedTurnEventForMatch(match, didBecomeActive: false)))
      )
    )
    self.mainQueue.run()
  }
}
