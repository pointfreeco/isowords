import BottomMenu
import ClientModels
import Combine
import ComposableArchitecture
import ComposableGameCenter
@_spi(Concurrency) import Dependencies
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

@MainActor
class TurnBasedTests: XCTestCase {
  let mainQueue = DispatchQueue.test
  let mainRunLoop = RunLoop.test

  func testNewGame() async throws {
    try await withMainSerialExecutor {
      let didEndTurnWithRequest = ActorIsolated<TurnBasedMatchClient.EndTurnRequest?>(nil)
      let didSaveCurrentTurn = ActorIsolated(false)

      let listener = AsyncStreamProducer<LocalPlayerClient.ListenerEvent>()

      let newMatch = update(TurnBasedMatch.new) { $0.creationDate = self.mainRunLoop.now.date }

      let currentPlayer = CurrentPlayerEnvelope.mock
      let dailyChallenges = [
        FetchTodaysDailyChallengeResponse(
          dailyChallenge: .init(
            endsAt: self.mainRunLoop.now.date,
            gameMode: .unlimited,
            id: .init(rawValue: .dailyChallengeId),
            language: .en
          ),
          yourResult: .init(outOf: 0, rank: nil, score: nil)
        ),
        FetchTodaysDailyChallengeResponse(
          dailyChallenge: .init(
            endsAt: self.mainRunLoop.now.date,
            gameMode: .timed,
            id: .init(rawValue: .dailyChallengeId),
            language: .en
          ),
          yourResult: .init(outOf: 0, rank: nil, score: nil)
        ),
      ]
      let weekInReview = FetchWeekInReviewResponse(ranks: [], word: nil)
      let store = TestStore(
        initialState: AppReducer.State(
          home: .init(destination: .multiplayer(.init(hasPastGames: false)))
        ),
        reducer: AppReducer()
      )

      store.dependencies.didFinishLaunching()

      store.dependencies.apiClient.apiRequest = { @Sendable route in
        switch route {
        case .dailyChallenge(.today):
          return try (JSONEncoder().encode(dailyChallenges), .init())
        case .leaderboard(.weekInReview):
          return try (JSONEncoder().encode(weekInReview), .init())
        default:
          return try await Task.never()
        }
      }
      store.dependencies.apiClient.authenticate = { _ in .mock }
      store.dependencies.apiClient.currentPlayer = { currentPlayer }
      store.dependencies.audioPlayer.loop = { _ in }
      store.dependencies.audioPlayer.play = { _ in }
      store.dependencies.audioPlayer.stop = { _ in }
      store.dependencies.build.number = { 42 }
      store.dependencies.deviceId.id = { .deviceId }
      store.dependencies.dictionary.contains = { word, _ in word == "CAB" }
      store.dependencies.dictionary.randomCubes = { _ in .mock }
      store.dependencies.feedbackGenerator = .noop
      store.dependencies.fileClient.save = { @Sendable _, _ in }
      store.dependencies.fileClient.load = { @Sendable _ in try await Task.never() }
      store.dependencies.gameCenter.localPlayer.authenticate = {}
      store.dependencies.gameCenter.localPlayer.listener = { listener.stream }
      store.dependencies.gameCenter.localPlayer.localPlayer = { .mock }
      store.dependencies.gameCenter.turnBasedMatch.endTurn = { await didEndTurnWithRequest.setValue($0) }
      store.dependencies.gameCenter.turnBasedMatch.loadMatches = { [] }
      store.dependencies.gameCenter.turnBasedMatch.saveCurrentTurn = { _, _ in
        await didSaveCurrentTurn.setValue(true)
      }
      store.dependencies.gameCenter.turnBasedMatchmakerViewController.dismiss = {}
      store.dependencies.gameCenter.turnBasedMatchmakerViewController.present = { @Sendable _ in }
      store.dependencies.lowPowerMode.start = { .never }
      store.dependencies.mainRunLoop = self.mainRunLoop.eraseToAnyScheduler()
      store.dependencies.serverConfig.config = { .init() }
      store.dependencies.serverConfig.refresh = { .init() }
      store.dependencies.userDefaults.setInteger = { _, _ in }
      store.dependencies.timeZone = .newYork

      let didFinishLaunchingTask = await store.send(.appDelegate(.didFinishLaunching))
      let homeTask = await store.send(.home(.task))

      await store.receive(.home(.authenticationResponse(.mock)))
      await store.receive(.home(.serverConfigResponse(.init()))) {
        $0.home.hasChangelog = true
      }
      await store.receive(.home(.dailyChallengeResponse(.success(dailyChallenges)))) {
        $0.home.dailyChallenges = dailyChallenges
      }
      await store.receive(.home(.weekInReviewResponse(.success(weekInReview)))) {
        $0.home.weekInReview = weekInReview
      }

      await self.mainRunLoop.advance()
      await store.receive(
        .home(.activeMatchesResponse(.success(.init(matches: [], hasPastTurnBasedGames: false))))
      )

      await store.send(.home(.destination(.presented(.multiplayer(.startButtonTapped)))))

      listener.continuation
        .yield(.turnBased(.receivedTurnEventForMatch(newMatch, didBecomeActive: true)))
      await self.mainRunLoop.advance()

      let initialGameState = Game.State(
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
      await store.receive(
        .gameCenter(.listener(.turnBased(.receivedTurnEventForMatch(newMatch, didBecomeActive: true))))
      ) {
        $0.game = initialGameState
        try XCTUnwrap(&$0.game) {
          try XCTUnwrap(&$0.turnBasedContext) {
            $0.metadata.lastOpenedAt = store.dependencies.mainRunLoop.now.date
          }
        }
      }
      store.dependencies.userDefaults.override(integer: 0, forKey: "multiplayerOpensCount")
      store.dependencies.userDefaults.setInteger = { int, key in
        XCTAssertNoDifference(int, 1)
        XCTAssertNoDifference(key, "multiplayerOpensCount")
      }
      await store.receive(
        .home(.activeMatchesResponse(.success(.init(matches: [], hasPastTurnBasedGames: false))))
      )
      let gameTask = await store.send(.currentGame(.game(.task)))

      await store.receive(.currentGame(.game(.matchesLoaded(.success([])))))
      await store.receive(.currentGame(.game(.gameLoaded))) {
        try XCTUnwrap(&$0.game) {
          $0.isGameLoaded = true
        }
      }

      await self.mainRunLoop.advance()

      await didSaveCurrentTurn.withValue { XCTAssert($0) }

      let index = LatticePoint(x: .two, y: .two, z: .two)
      let C = IndexedCubeFace(index: index, side: .top)
      let A = IndexedCubeFace(index: index, side: .left)
      let B = IndexedCubeFace(index: index, side: .right)

      await store.send(.currentGame(.game(.tap(.began, C)))) {
        try XCTUnwrap(&$0.game) {
          $0.optimisticallySelectedFace = C
          $0.selectedWord = [C]
        }
      }
      await store.send(.currentGame(.game(.tap(.ended, C)))) {
        try XCTUnwrap(&$0.game) {
          $0.optimisticallySelectedFace = nil
        }
      }
      await store.send(.currentGame(.game(.tap(.began, A)))) {
        try XCTUnwrap(&$0.game) {
          $0.optimisticallySelectedFace = A
          $0.selectedWord = [C, A]
        }
      }
      await store.send(.currentGame(.game(.tap(.ended, A)))) {
        try XCTUnwrap(&$0.game) {
          $0.optimisticallySelectedFace = nil
        }
      }
      await store.send(.currentGame(.game(.tap(.began, B)))) {
        try XCTUnwrap(&$0.game) {
          $0.optimisticallySelectedFace = B
          $0.selectedWord = [C, A, B]
          $0.selectedWordIsValid = true
        }
      }
      await store.send(.currentGame(.game(.tap(.ended, B)))) {
        try XCTUnwrap(&$0.game) {
          $0.optimisticallySelectedFace = nil
        }
      }

      let updatedGameState = try update(initialGameState) {
        $0.isGameLoaded = true
        $0.moves = [
          .init(
            playedAt: self.mainRunLoop.now.date,
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
          $0.metadata.lastOpenedAt = store.dependencies.mainRunLoop.now.date
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
                lastOpenedAt: store.dependencies.mainRunLoop.now.date,
                playerIndexToId: [0: currentPlayer.player.id]
              )
            ),
            gameState: updatedGameState,
            playerId: currentPlayer.player.id
          )
        )
      }
      store.dependencies.gameCenter.turnBasedMatch.load = { _ in updatedMatch }

      await store.send(.currentGame(.game(.submitButtonTapped(reaction: .angel)))) {
        $0.game = updatedGameState
      }
      try await didEndTurnWithRequest.withValue {
        XCTAssertNoDifference(
          $0,
          .init(
            for: newMatch.matchId,
            matchData: Data(
              turnBasedMatchData: TurnBasedMatchData(
                context: try XCTUnwrap(store.state.currentGame.game?.turnBasedContext),
                gameState: try XCTUnwrap(store.state.game),
                playerId: currentPlayer.player.id
              )
            ),
            message: "Blob played CAB! (+27 😇)"
          )
        )
      }

      await store.receive(
        .currentGame(.game(.gameCenter(.turnBasedMatchResponse(.success(updatedMatch)))))
      ) {
        try XCTUnwrap(&$0.game) {
          $0.turnBasedContext = .init(
            localPlayer: .mock,
            match: updatedMatch,
            metadata: .init(
              lastOpenedAt: store.dependencies.mainRunLoop.now.date,
              playerIndexToId: [0: currentPlayer.player.id]
            )
          )
        }
      }

      await gameTask.cancel()
      await homeTask.cancel()
      await didFinishLaunchingTask.cancel()
    }
  }

  func testResumeGame() async {
    await withMainSerialExecutor {
      let listener = AsyncStreamProducer<LocalPlayerClient.ListenerEvent>()

      let dailyChallenges = [
        FetchTodaysDailyChallengeResponse(
          dailyChallenge: .init(
            endsAt: self.mainRunLoop.now.date,
            gameMode: .unlimited,
            id: .init(rawValue: .dailyChallengeId),
            language: .en
          ),
          yourResult: .init(outOf: 0, rank: nil, score: nil)
        ),
        FetchTodaysDailyChallengeResponse(
          dailyChallenge: .init(
            endsAt: self.mainRunLoop.now.date,
            gameMode: .timed,
            id: .init(rawValue: .dailyChallengeId),
            language: .en
          ),
          yourResult: .init(outOf: 0, rank: nil, score: nil)
        ),
      ]
      let weekInReview = FetchWeekInReviewResponse(ranks: [], word: nil)

      let store = TestStore(
        initialState: AppReducer.State(),
        reducer: AppReducer()
      )

      store.dependencies.didFinishLaunching()
      store.dependencies.apiClient.authenticate = { _ in .mock }
      store.dependencies.build.number = { 42 }
      store.dependencies.apiClient.currentPlayer = { nil }
      store.dependencies.apiClient.apiRequest = { @Sendable route in
        switch route {
        case .dailyChallenge(.today):
          return try (JSONEncoder().encode(dailyChallenges), .init())
        case .leaderboard(.weekInReview):
          return try (JSONEncoder().encode(weekInReview), .init())
        default:
          return try await Task.never()
        }
      }
      store.dependencies.deviceId.id = { .deviceId }
      store.dependencies.fileClient.save = { @Sendable _, _ in }
      store.dependencies.gameCenter.localPlayer.authenticate = {}
      store.dependencies.gameCenter.localPlayer.listener = { listener.stream }
      store.dependencies.gameCenter.localPlayer.localPlayer = { .mock }
      store.dependencies.gameCenter.turnBasedMatch.saveCurrentTurn = { _, _ in }
      store.dependencies.gameCenter.turnBasedMatch.loadMatches = { [] }
      store.dependencies.gameCenter.turnBasedMatchmakerViewController.dismiss = {}
      store.dependencies.serverConfig.config = { .init() }
      store.dependencies.timeZone = .newYork

      let didFinishLaunchingTask = await store.send(.appDelegate(.didFinishLaunching))
      let homeTask = await store.send(.home(.task))

      await store.receive(.home(.authenticationResponse(.mock)))
      await store.receive(.home(.serverConfigResponse(.init()))) {
        $0.home.hasChangelog = true
      }
      await store.receive(.home(.dailyChallengeResponse(.success(dailyChallenges)))) {
        $0.home.dailyChallenges = dailyChallenges
      }
      await store.receive(.home(.weekInReviewResponse(.success(weekInReview)))) {
        $0.home.weekInReview = weekInReview
      }

      await store.receive(
        .home(.activeMatchesResponse(.success(.init(matches: [], hasPastTurnBasedGames: false))))
      )

      listener.continuation
        .yield(.turnBased(.receivedTurnEventForMatch(.inProgress, didBecomeActive: true)))

      await store.receive(
        .gameCenter(
          .listener(
            .turnBased(
              .receivedTurnEventForMatch(.inProgress, didBecomeActive: true)
            )
          )
        )
      ) {
        $0.game = update(
          Game.State(
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
        ) { $0.gameCurrentTime = self.mainRunLoop.now.date }
      }
      await store.receive(
        .home(.activeMatchesResponse(.success(.init(matches: [], hasPastTurnBasedGames: false))))
      )


      await homeTask.cancel()
      await didFinishLaunchingTask.cancel()
    }
  }

  func testResumeForfeitedGame() async {
    await withMainSerialExecutor {
      let listener = AsyncStreamProducer<LocalPlayerClient.ListenerEvent>()
      
      let dailyChallenges = [
        FetchTodaysDailyChallengeResponse(
          dailyChallenge: .init(
            endsAt: self.mainRunLoop.now.date,
            gameMode: .unlimited,
            id: .init(rawValue: .dailyChallengeId),
            language: .en
          ),
          yourResult: .init(outOf: 0, rank: nil, score: nil)
        ),
        FetchTodaysDailyChallengeResponse(
          dailyChallenge: .init(
            endsAt: self.mainRunLoop.now.date,
            gameMode: .timed,
            id: .init(rawValue: .dailyChallengeId),
            language: .en
          ),
          yourResult: .init(outOf: 0, rank: nil, score: nil)
        ),
      ]
      let weekInReview = FetchWeekInReviewResponse(ranks: [], word: nil)
      
      let store = TestStore(
        initialState: AppReducer.State(),
        reducer: AppReducer()
      )
      
      store.dependencies.didFinishLaunching()
      store.dependencies.apiClient.authenticate = { _ in .mock }
      store.dependencies.apiClient.currentPlayer = { nil }
      store.dependencies.apiClient.apiRequest = { @Sendable route in
        switch route {
        case .dailyChallenge(.today):
          return try (JSONEncoder().encode(dailyChallenges), .init())
        case .leaderboard(.weekInReview):
          return try (JSONEncoder().encode(weekInReview), .init())
        default:
          return try await Task.never()
        }
      }
      store.dependencies.build.number = { 42 }
      store.dependencies.deviceId.id = { .deviceId }
      store.dependencies.fileClient.save = { @Sendable _, _ in }
      store.dependencies.gameCenter.localPlayer.authenticate = {}
      store.dependencies.gameCenter.localPlayer.listener = { listener.stream }
      store.dependencies.gameCenter.localPlayer.localPlayer = { .mock }
      store.dependencies.gameCenter.turnBasedMatch.loadMatches = { [] }
      store.dependencies.gameCenter.turnBasedMatchmakerViewController.dismiss = {}
      store.dependencies.serverConfig.config = { .init() }
      store.dependencies.timeZone = .newYork
      
      let didFinishLaunchingTask = await store.send(.appDelegate(.didFinishLaunching))
      let homeTask = await store.send(.home(.task))
      await store.receive(.home(.authenticationResponse(.mock)))
      
      await store.receive(.home(.serverConfigResponse(.init()))) {
        $0.home.hasChangelog = true
      }
      await store.receive(.home(.dailyChallengeResponse(.success(dailyChallenges)))) {
        $0.home.dailyChallenges = dailyChallenges
      }
      await store.receive(.home(.weekInReviewResponse(.success(weekInReview)))) {
        $0.home.weekInReview = weekInReview
      }
      await store.receive(
        .home(.activeMatchesResponse(.success(.init(matches: [], hasPastTurnBasedGames: false))))
      )
      
      listener.continuation
        .yield(.turnBased(.receivedTurnEventForMatch(.forfeited, didBecomeActive: true)))
      
      await store.receive(
        .gameCenter(
          .listener(
            .turnBased(
              .receivedTurnEventForMatch(.forfeited, didBecomeActive: true)
            )
          )
        )
      ) {
        var gameState = Game.State(
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
        gameState.destination = .gameOver(
          GameOver.State(
            completedGame: CompletedGame(gameState: gameState),
            isDemo: false,
            turnBasedContext: .init(
              localPlayer: .mock,
              match: .forfeited,
              metadata: .init(lastOpenedAt: nil, playerIndexToId: [:])
            )
          )
        )
        gameState.gameCurrentTime = self.mainRunLoop.now.date
        $0.game = gameState
      }
      await store.receive(
        .home(.activeMatchesResponse(.success(.init(matches: [], hasPastTurnBasedGames: false))))
      )
      
      
      await homeTask.cancel()
      await didFinishLaunchingTask.cancel()
    }
  }

  func testRemovingCubes() async throws {
    let didEndTurnWithRequest = ActorIsolated<TurnBasedMatchClient.EndTurnRequest?>(nil)
    let match = update(TurnBasedMatch.inProgress) {
      $0.creationDate = self.mainRunLoop.now.date.addingTimeInterval(-60*5)
      $0.participants = [.local, .remote]
    }

    let initialGameState = Game.State(
      cubes: .mock,
      gameContext: .turnBased(
        .init(
          localPlayer: .mock,
          match: match,
          metadata: .init(lastOpenedAt: nil, playerIndexToId: [:])
        )
      ),
      gameCurrentTime: self.mainRunLoop.now.date,
      gameMode: .unlimited,
      gameStartTime: match.creationDate,
      secondsPlayed: 0
    )
    let store = TestStore(
      initialState: AppReducer.State(game: initialGameState),
      reducer: AppReducer()
    )

    store.dependencies.apiClient.currentPlayer = { nil }
    store.dependencies.audioPlayer.play = { _ in }
    store.dependencies.gameCenter.localPlayer.localPlayer = { .mock }
    store.dependencies.gameCenter.turnBasedMatch.saveCurrentTurn = { _, _ in }
    store.dependencies.gameCenter.turnBasedMatch.endTurn = { await didEndTurnWithRequest.setValue($0) }
    store.dependencies.mainRunLoop = self.mainRunLoop.eraseToAnyScheduler()

    await store.send(.currentGame(.game(.doubleTap(index: .zero)))) {
      try XCTUnwrap(&$0.game) {
        $0.bottomMenu = .removeCube(index: .zero, state: $0, isTurnEndingRemoval: false)
      }
    }

    var updatedGameState = update(initialGameState) {
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
    store.dependencies.gameCenter.turnBasedMatch.load = { [updatedMatch] _ in updatedMatch }

    await store.send(.currentGame(.game(.confirmRemoveCube(.zero)))) {
      $0.game = updatedGameState
    }
    await store.receive(
      .currentGame(.game(.gameCenter(.turnBasedMatchResponse(.success(updatedMatch)))))
    ) {
      try XCTUnwrap(&$0.game) {
        try XCTUnwrap(&$0.turnBasedContext) {
          $0.match = updatedMatch
        }
      }
    }
    await store.send(.currentGame(.game(.doubleTap(index: .init(x: .zero, y: .zero, z: .one))))) {
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
          playedAt: self.mainRunLoop.now.date,
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
    store.dependencies.gameCenter.turnBasedMatch.load = { [updatedMatch] _ in updatedMatch }

    await store.send(.currentGame(.game(.confirmRemoveCube(.init(x: .zero, y: .zero, z: .one))))) {
      $0.game = updatedGameState
    }
    await store.receive(.currentGame(.game(.gameCenter(.turnBasedMatchResponse(.success(updatedMatch)))))) {
      try XCTUnwrap(&$0.game) {
        try XCTUnwrap(&$0.turnBasedContext) {
          $0.match = updatedMatch
        }
      }
    }
    await store.send(.currentGame(.game(.doubleTap(index: .init(x: .zero, y: .zero, z: .two)))))

    try await didEndTurnWithRequest.withValue {
      XCTAssertNoDifference(
        $0,
        .init(
          for: match.matchId,
          matchData: Data(
            turnBasedMatchData: TurnBasedMatchData(
              context: try XCTUnwrap(store.state.game?.turnBasedContext),
              gameState: try XCTUnwrap(store.state.game),
              playerId: nil
            )
          ),
          message: "Blob removed cubes!"
        )
      )
    }
  }

  func testRematch() async {
    let localParticipant = TurnBasedParticipant.local
    let match = update(TurnBasedMatch.inProgress) {
      $0.currentParticipant = localParticipant
      $0.creationDate = self.mainRunLoop.now.date.addingTimeInterval(-60*5)
      $0.participants = [localParticipant, .remote]
    }
    let didRematchWithId = ActorIsolated<TurnBasedMatch.Id?>(nil)

    let newMatch = update(TurnBasedMatch.new) { $0.creationDate = self.mainRunLoop.now.date }

    let store = TestStore(
      initialState: AppReducer.State(
        game: update(
          Game.State(
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
          $0.destination = .gameOver(
            GameOver.State(
              completedGame: CompletedGame(gameState: $0),
              isDemo: false
            )
          )
        }
      ),
      reducer: AppReducer()
    )

    store.dependencies.apiClient.currentPlayer = { nil }
    store.dependencies.dictionary.randomCubes = { _ in .mock }
    store.dependencies.fileClient.load = { @Sendable _ in try await Task.never() }
    store.dependencies.gameCenter.localPlayer.localPlayer = {
      update(.authenticated) { $0.player = localParticipant.player! }
    }
    store.dependencies.gameCenter.turnBasedMatch.rematch = {
      await didRematchWithId.setValue($0)
      return newMatch
    }
    store.dependencies.gameCenter.turnBasedMatch.saveCurrentTurn = { _, _ in }
    store.dependencies.gameCenter.turnBasedMatchmakerViewController.dismiss = {}
    store.dependencies.mainQueue = self.mainQueue.eraseToAnyScheduler()
    store.dependencies.mainRunLoop = self.mainRunLoop.eraseToAnyScheduler()

    await store.send(
      .currentGame(.game(.destination(.presented(.gameOver(.rematchButtonTapped)))))
    ) {
      $0.game = nil
    }
    await didRematchWithId.withValue { XCTAssertNoDifference($0, match.matchId) }
    await self.mainQueue.advance()

    await store.receive(.gameCenter(.rematchResponse(.success(newMatch)))) {
      $0.currentGame = GameFeature.State(
        game: Game.State(
          cubes: .mock,
          gameContext: .turnBased(
            .init(
              localPlayer: .mock,
              match: newMatch,
              metadata: .init(lastOpenedAt: self.mainRunLoop.now.date, playerIndexToId: [:])
            )
          ),
          gameCurrentTime: self.mainRunLoop.now.date,
          gameMode: .unlimited,
          gameStartTime: newMatch.creationDate
        ),
        settings: $0.home.settings
      )
    }
  }

  func testGameCenterNotification_ShowsRecentTurn() async {
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

    let notificationBannerRequest = ActorIsolated<GameCenterClient.NotificationBannerRequest?>(nil)

    let store = TestStore(
      initialState: AppReducer.State(),
      reducer: AppReducer()
    )

    store.dependencies.gameCenter.localPlayer.localPlayer = { .authenticated }
    store.dependencies.gameCenter.showNotificationBanner = { await notificationBannerRequest.setValue($0) }
    store.dependencies.mainQueue = self.mainQueue.eraseToAnyScheduler()
    store.dependencies.mainRunLoop = self.mainRunLoop.eraseToAnyScheduler()

    await store.send(
      .gameCenter(
        .listener(.turnBased(.receivedTurnEventForMatch(match, didBecomeActive: false)))
      )
    )

    await self.mainQueue.advance()
    await notificationBannerRequest.withValue {
      XCTAssertNoDifference(
        $0,
        GameCenterClient.NotificationBannerRequest(
          title: "Blob played ABC!",
          message: nil
        )
      )
    }
  }

  func testGameCenterNotification_DoesNotShow() async {
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

    let store = TestStore(
      initialState: AppReducer.State(),
      reducer: AppReducer()
    )

    store.dependencies.gameCenter.localPlayer.localPlayer = { .authenticated }
    store.dependencies.mainQueue = self.mainQueue.eraseToAnyScheduler()
    store.dependencies.mainRunLoop = self.mainRunLoop.eraseToAnyScheduler()

    await store.send(
      .gameCenter(
        .listener(.turnBased(.receivedTurnEventForMatch(match, didBecomeActive: false)))
      )
    )
    await self.mainQueue.run()
  }
}
