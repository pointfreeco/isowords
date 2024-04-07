import BottomMenu
import ClientModels
import Combine
import ComposableArchitecture
import ComposableGameCenter
@_spi(Concurrency) import Dependencies
import DictionaryClient
import GameKit
import GameCore
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
        )
      ) {
        AppReducer()
      } withDependencies: {
        $0.didFinishLaunching()

        $0.apiClient.apiRequest = { @Sendable route in
          switch route {
          case .dailyChallenge(.today):
            return try (JSONEncoder().encode(dailyChallenges), .init())
          case .leaderboard(.weekInReview):
            return try (JSONEncoder().encode(weekInReview), .init())
          default:
            return try await Task.never()
          }
        }
        $0.apiClient.authenticate = { _ in .mock }
        $0.apiClient.currentPlayer = { currentPlayer }
        $0.audioPlayer.loop = { _ in }
        $0.audioPlayer.play = { _ in }
        $0.audioPlayer.stop = { _ in }
        $0.build.number = { 42 }
        $0.deviceId.id = { .deviceId }
        $0.dictionary.contains = { word, _ in word == "CAB" }
        $0.dictionary.randomCubes = { _ in .mock }
        $0.feedbackGenerator = .noop
        $0.gameCenter.localPlayer.authenticate = {}
        $0.gameCenter.localPlayer.listener = { listener.stream }
        $0.gameCenter.localPlayer.localPlayer = { .mock }
        $0.gameCenter.turnBasedMatch.endTurn = { await didEndTurnWithRequest.setValue($0) }
        $0.gameCenter.turnBasedMatch.loadMatches = { [] }
        $0.gameCenter.turnBasedMatch.saveCurrentTurn = { _, _ in
          await didSaveCurrentTurn.setValue(true)
        }
        $0.gameCenter.turnBasedMatchmakerViewController.dismiss = {}
        $0.gameCenter.turnBasedMatchmakerViewController.present = { @Sendable _ in }
        $0.lowPowerMode.start = { .never }
        $0.mainRunLoop = self.mainRunLoop.eraseToAnyScheduler()
        $0.serverConfig.config = { .init() }
        $0.serverConfig.refresh = { .init() }
        $0.userDefaults.setInteger = { _, _ in }
        $0.timeZone = .newYork
      }

      let didFinishLaunchingTask = await store.send(.appDelegate(.didFinishLaunching))
      let homeTask = await store.send(.home(.task))

      await store.receive(\.home.authenticationResponse)
      await store.receive(\.home.serverConfigResponse) {
        $0.home.hasChangelog = true
      }
      await store.receive(\.home.activeMatchesResponse.success)
      await store.receive(\.home.dailyChallengeResponse.success) {
        $0.home.dailyChallenges = dailyChallenges
      }
      await store.receive(\.home.weekInReviewResponse.success) {
        $0.home.weekInReview = weekInReview
      }

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
      await store.receive(\.gameCenter.listener.turnBased.receivedTurnEventForMatch) {
        $0.destination = .game(initialGameState)
        $0.$destination[case: \.game]?.gameContext.modify(\.turnBased) {
          $0.metadata.lastOpenedAt = store.dependencies.mainRunLoop.now.date
        }
      }
      store.dependencies.userDefaults.override(integer: 0, forKey: "multiplayerOpensCount")
      store.dependencies.userDefaults.setInteger = { int, key in
        XCTAssertNoDifference(int, 1)
        XCTAssertNoDifference(key, "multiplayerOpensCount")
      }
      await store.receive(\.home.activeMatchesResponse.success)

      let gameTask = await store.send(.destination(.presented(.game(.task))))

      await store.receive(\.destination.game.matchesLoaded.success)
      await store.receive(\.destination.game.gameLoaded) {
        $0.$destination[case: \.game]?.isGameLoaded = true
      }

      await self.mainRunLoop.advance()

      await didSaveCurrentTurn.withValue { XCTAssert($0) }

      let index = LatticePoint(x: .two, y: .two, z: .two)
      let C = IndexedCubeFace(index: index, side: .top)
      let A = IndexedCubeFace(index: index, side: .left)
      let B = IndexedCubeFace(index: index, side: .right)

      await store.send(.destination(.presented(.game(.tap(.began, C))))) {
        $0.$destination[case: \.game]?.optimisticallySelectedFace = C
        $0.$destination[case: \.game]?.selectedWord = [C]
      }
      await store.send(.destination(.presented(.game(.tap(.ended, C))))) {
        $0.$destination[case: \.game]?.optimisticallySelectedFace = nil
      }
      await store.send(.destination(.presented(.game(.tap(.began, A))))) {
        $0.$destination[case: \.game]?.optimisticallySelectedFace = A
        $0.$destination[case: \.game]?.selectedWord = [C, A]
      }
      await store.send(.destination(.presented(.game(.tap(.ended, A))))) {
        $0.$destination[case: \.game]?.optimisticallySelectedFace = nil
      }
      await store.send(.destination(.presented(.game(.tap(.began, B))))) {
        $0.$destination[case: \.game]?.optimisticallySelectedFace = B
        $0.$destination[case: \.game]?.selectedWord = [C, A, B]
        $0.$destination[case: \.game]?.selectedWordIsValid = true
      }
      await store.send(.destination(.presented(.game(.tap(.ended, B))))) {
        $0.$destination[case: \.game]?.optimisticallySelectedFace = nil
      }

      let updatedGameState = update(initialGameState) {
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
        $0.gameContext.modify(\.turnBased) {
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

      await store.send(.destination(.presented(.game(.submitButtonTapped(reaction: .angel))))) {
        $0.destination = .game(updatedGameState)
      }
      try await didEndTurnWithRequest.withValue {
        let game = try XCTUnwrap(store.state.destination?.game)
        XCTAssertNoDifference(
          $0,
          .init(
            for: newMatch.matchId,
            matchData: Data(
              turnBasedMatchData: TurnBasedMatchData(
                context: try XCTUnwrap(game.gameContext.turnBased),
                gameState: game,
                playerId: currentPlayer.player.id
              )
            ),
            message: "Blob played CAB! (+27 😇)"
          )
        )
      }

      await store.receive(\.destination.game.gameCenter.turnBasedMatchResponse.success) {
        $0.$destination[case: \.game]?.gameContext = .turnBased(
          .init(
            localPlayer: .mock,
            match: updatedMatch,
            metadata: .init(
              lastOpenedAt: store.dependencies.mainRunLoop.now.date,
              playerIndexToId: [0: currentPlayer.player.id]
            )
          )
        )
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
        initialState: AppReducer.State()
      ) {
        AppReducer()
      } withDependencies: {
        $0.didFinishLaunching()
        $0.apiClient.authenticate = { _ in .mock }
        $0.build.number = { 42 }
        $0.apiClient.currentPlayer = { nil }
        $0.apiClient.apiRequest = { @Sendable route in
          switch route {
          case .dailyChallenge(.today):
            return try (JSONEncoder().encode(dailyChallenges), .init())
          case .leaderboard(.weekInReview):
            return try (JSONEncoder().encode(weekInReview), .init())
          default:
            return try await Task.never()
          }
        }
        $0.deviceId.id = { .deviceId }
        $0.gameCenter.localPlayer.authenticate = {}
        $0.gameCenter.localPlayer.listener = { listener.stream }
        $0.gameCenter.localPlayer.localPlayer = { .mock }
        $0.gameCenter.turnBasedMatch.saveCurrentTurn = { _, _ in }
        $0.gameCenter.turnBasedMatch.loadMatches = { [] }
        $0.gameCenter.turnBasedMatchmakerViewController.dismiss = {}
        $0.serverConfig.config = { .init() }
        $0.timeZone = .newYork
      }

      let didFinishLaunchingTask = await store.send(.appDelegate(.didFinishLaunching))
      let homeTask = await store.send(.home(.task))

      await store.receive(\.home.authenticationResponse)
      await store.receive(\.home.serverConfigResponse) {
        $0.home.hasChangelog = true
      }
      await store.receive(\.home.activeMatchesResponse.success)
      await store.receive(\.home.dailyChallengeResponse.success) {
        $0.home.dailyChallenges = dailyChallenges
      }
      await store.receive(\.home.weekInReviewResponse.success) {
        $0.home.weekInReview = weekInReview
      }

      listener.continuation
        .yield(.turnBased(.receivedTurnEventForMatch(.inProgress, didBecomeActive: true)))

      await store.receive(\.gameCenter.listener.turnBased.receivedTurnEventForMatch) {
        $0.destination = .game(
          update(
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
        )
      }
      await store.receive(\.home.activeMatchesResponse.success)

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
      
      let store = TestStore(initialState: AppReducer.State()) {
        AppReducer()
      } withDependencies: {
        $0.didFinishLaunching()
        $0.apiClient.authenticate = { _ in .mock }
        $0.apiClient.currentPlayer = { nil }
        $0.apiClient.apiRequest = { @Sendable route in
          switch route {
          case .dailyChallenge(.today):
            return try (JSONEncoder().encode(dailyChallenges), .init())
          case .leaderboard(.weekInReview):
            return try (JSONEncoder().encode(weekInReview), .init())
          default:
            return try await Task.never()
          }
        }
        $0.build.number = { 42 }
        $0.deviceId.id = { .deviceId }
        $0.gameCenter.localPlayer.authenticate = {}
        $0.gameCenter.localPlayer.listener = { listener.stream }
        $0.gameCenter.localPlayer.localPlayer = { .mock }
        $0.gameCenter.turnBasedMatch.loadMatches = { [] }
        $0.gameCenter.turnBasedMatchmakerViewController.dismiss = {}
        $0.serverConfig.config = { .init() }
        $0.timeZone = .newYork
      }
      
      let didFinishLaunchingTask = await store.send(.appDelegate(.didFinishLaunching))
      let homeTask = await store.send(.home(.task))
      await store.receive(\.home.authenticationResponse)

      await store.receive(\.home.serverConfigResponse) {
        $0.home.hasChangelog = true
      }
      await store.receive(\.home.activeMatchesResponse.success)
      await store.receive(\.home.dailyChallengeResponse.success) {
        $0.home.dailyChallenges = dailyChallenges
      }
      await store.receive(\.home.weekInReviewResponse.success) {
        $0.home.weekInReview = weekInReview
      }
      
      listener.continuation
        .yield(.turnBased(.receivedTurnEventForMatch(.forfeited, didBecomeActive: true)))
      
      await store.receive(\.gameCenter.listener.turnBased.receivedTurnEventForMatch) {
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
        gameState.gameCurrentTime = self.mainRunLoop.now.date
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
        $0.destination = .game(gameState)
      }
      await store.receive(\.home.activeMatchesResponse.success)
      
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
      initialState: AppReducer.State(destination: .game(initialGameState))
    ) {
      AppReducer()
    } withDependencies: {
      $0.apiClient.currentPlayer = { nil }
      $0.audioPlayer.play = { _ in }
      $0.gameCenter.localPlayer.localPlayer = { .mock }
      $0.gameCenter.turnBasedMatch.saveCurrentTurn = { _, _ in }
      $0.gameCenter.turnBasedMatch.endTurn = { await didEndTurnWithRequest.setValue($0) }
      $0.mainRunLoop = self.mainRunLoop.eraseToAnyScheduler()
    }

    await store.send(.destination(.presented(.game(.doubleTap(index: .zero))))) {
      let game = try XCTUnwrap($0.$destination[case: \.game])
      $0.$destination[case: \.game]?.destination = .bottomMenu(
        .removeCube(index: .zero, state: game, isTurnEndingRemoval: false)
      )
    }

    var updatedGameState = update(initialGameState) {
      $0.destination = nil
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

    await store.send(
      .destination(
        .presented(.game(.destination(.presented(.bottomMenu(.confirmRemoveCube(.zero))))))
      )
    ) {
      $0.destination = .game(updatedGameState)
    }
    await store.receive(\.destination.game.gameCenter.turnBasedMatchResponse.success) {
      $0.$destination[case: \.game]?.gameContext.modify(\.turnBased) {
        $0.match = updatedMatch
      }
    }
    await store.send(
      .destination(.presented(.game(.doubleTap(index: .init(x: .zero, y: .zero, z: .one)))))
    ) {
      let game = try XCTUnwrap($0.$destination[case: \.game])
      $0.$destination[case: \.game]?.destination = .bottomMenu(
        .removeCube(
          index: .init(x: .zero, y: .zero, z: .one),
          state: game,
          isTurnEndingRemoval: true
        )
      )
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
      $0.gameContext.modify(\.turnBased) { $0.match = updatedMatch }
      $0.cubes.0.0.1.wasRemoved = true
      $0.destination = nil
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

    await store.send(
      .destination(
        .presented(
          .game(
            .destination(
              .presented(.bottomMenu(.confirmRemoveCube(.init(x: .zero, y: .zero, z: .one))))
            )
          )
        )
      )
    ) {
      $0.destination = .game(updatedGameState)
    }
    await store.receive(\.destination.game.gameCenter.turnBasedMatchResponse.success) {
      $0.$destination[case: \.game]?.gameContext.modify(\.turnBased) {
        $0.match = updatedMatch
      }
    }
    await store.send(
      .destination(.presented(.game(.doubleTap(index: .init(x: .zero, y: .zero, z: .two)))))
    )

    try await didEndTurnWithRequest.withValue {
      let game = try XCTUnwrap(store.state.destination?.game)
      XCTAssertNoDifference(
        $0,
        .init(
          for: match.matchId,
          matchData: Data(
            turnBasedMatchData: TurnBasedMatchData(
              context: try XCTUnwrap(game.gameContext.turnBased),
              gameState: game,
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
        destination: .game(
          update(
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
        )
      )
    ) {
      AppReducer()
    } withDependencies: {
      $0.apiClient.currentPlayer = { nil }
      $0.dictionary.randomCubes = { _ in .mock }
      $0.gameCenter.localPlayer.localPlayer = {
        update(.authenticated) { $0.player = localParticipant.player! }
      }
      $0.gameCenter.turnBasedMatch.rematch = {
        await didRematchWithId.setValue($0)
        return newMatch
      }
      $0.gameCenter.turnBasedMatch.saveCurrentTurn = { _, _ in }
      $0.gameCenter.turnBasedMatchmakerViewController.dismiss = {}
      $0.mainQueue = self.mainQueue.eraseToAnyScheduler()
      $0.mainRunLoop = self.mainRunLoop.eraseToAnyScheduler()
    }

    await store.send(
      .destination(.presented(.game(.destination(.presented(.gameOver(.rematchButtonTapped))))))
    ) {
      $0.destination = nil
    }
    await didRematchWithId.withValue { XCTAssertNoDifference($0, match.matchId) }
    await self.mainQueue.advance()

    await store.receive(\.gameCenter.rematchResponse.success) {
      $0.destination = .game(
        Game.State(
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
        )
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
      initialState: AppReducer.State()
    ) {
      AppReducer()
    } withDependencies: {
      $0.gameCenter.localPlayer.localPlayer = { .authenticated }
      $0.gameCenter.showNotificationBanner = { await notificationBannerRequest.setValue($0) }
      $0.mainQueue = self.mainQueue.eraseToAnyScheduler()
      $0.mainRunLoop = self.mainRunLoop.eraseToAnyScheduler()
    }

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
      initialState: AppReducer.State()
    ) {
      AppReducer()
    } withDependencies: {
      $0.gameCenter.localPlayer.localPlayer = { .authenticated }
      $0.mainQueue = self.mainQueue.eraseToAnyScheduler()
      $0.mainRunLoop = self.mainRunLoop.eraseToAnyScheduler()
    }

    await store.send(
      .gameCenter(
        .listener(.turnBased(.receivedTurnEventForMatch(match, didBecomeActive: false)))
      )
    )
    await self.mainQueue.run()
  }
}
