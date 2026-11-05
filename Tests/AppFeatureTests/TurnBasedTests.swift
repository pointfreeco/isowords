import BottomMenu
import ClientModels
import ComposableArchitecture
import ComposableGameCenter
import ConcurrencyExtras
import CustomDump
import Dependencies
import DictionaryClient
import GameCore
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
  let clock = TestClock<Duration>()
  let now = Date(timeIntervalSinceReferenceDate: 0)

  func testNewGame() async throws {
    try await withMainSerialExecutor {
      let didEndTurnWithRequest = LockIsolated<TurnBasedMatchClient.EndTurnRequest?>(nil)
      let didSaveCurrentTurn = LockIsolated(false)
      let multiplayerOpensCounts = LockIsolated<[Int]>([])
      let loadedMatch = LockIsolated<TurnBasedMatch?>(nil)

      let listener = AsyncStreamProducer<LocalPlayerClient.ListenerEvent>()

      let newMatch = update(TurnBasedMatch.new) { $0.creationDate = self.now }

      let currentPlayer = CurrentPlayerEnvelope.mock
      let dailyChallenges = [
        FetchTodaysDailyChallengeResponse(
          dailyChallenge: .init(
            endsAt: self.now,
            gameMode: .unlimited,
            id: .init(rawValue: .dailyChallengeId),
            language: .en
          ),
          yourResult: .init(outOf: 0, rank: nil, score: nil)
        ),
        FetchTodaysDailyChallengeResponse(
          dailyChallenge: .init(
            endsAt: self.now,
            gameMode: .timed,
            id: .init(rawValue: .dailyChallengeId),
            language: .en
          ),
          yourResult: .init(outOf: 0, rank: nil, score: nil)
        ),
      ]
      let weekInReview = FetchWeekInReviewResponse(ranks: [], word: nil)
      let store = withDependencies {
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
        $0.build.number = { 42 }
        $0.dictionary.contains = { word, _ in word == "CAB" }
        $0.dictionary.randomCubes = { _ in .mock }
        $0.fileClient.save = { @Sendable _, _ in }
        $0.gameCenter.localPlayer.listener = { listener.stream }
        $0.gameCenter.localPlayer.localPlayer = { .mock }
        $0.gameCenter.turnBasedMatch.endTurn = { didEndTurnWithRequest.setValue($0) }
        $0.gameCenter.turnBasedMatch.load = { _ in try XCTUnwrap(loadedMatch.value) }
        $0.gameCenter.turnBasedMatch.saveCurrentTurn = { _, _ in
          didSaveCurrentTurn.setValue(true)
        }
        $0.gameCenter.turnBasedMatchmakerViewController.dismiss = {}
        $0.gameCenter.turnBasedMatchmakerViewController.present = { @Sendable _ in }
        $0.userDefaults.setInteger = { int, key in
          expectNoDifference(key, "multiplayerOpensCount")
          multiplayerOpensCounts.withValue { $0.append(int) }
        }
      } operation: {
        TestStore(
          initialState: AppReducer.State(
            home: .init(destination: .multiplayer(.init(hasPastGames: false)))
          )
        ) {
          AppReducer()
            .environment(\.continuousClock, self.clock)
        }
      }

      await Task.megaYield()
      store.expect {
        $0.home.hasChangelog = true
        $0.home.dailyChallenges = dailyChallenges
        $0.home.weekInReview = weekInReview
      }

      await store.send(to: \.home.destination?.multiplayer, .startButtonTapped)?.value

      listener.continuation
        .yield(.turnBased(.receivedTurnEventForMatch(newMatch, didBecomeActive: true)))
      await self.clock.advance()
      await Task.megaYield()

      let initialGameState = try update(
        Game.State(
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
      ) {
        try $0.gameContext.modify(\.turnBased) {
          $0.metadata.lastOpenedAt = self.now
        }
      }
      store.expect {
        $0.destination = .game(snap(update(initialGameState) { $0.isGameLoaded = true }))
      }
      XCTAssert(didSaveCurrentTurn.value)
      expectNoDifference(multiplayerOpensCounts.value, [1])

      let index = LatticePoint(x: .two, y: .two, z: .two)
      let C = IndexedCubeFace(index: index, side: .top)
      let A = IndexedCubeFace(index: index, side: .left)
      let B = IndexedCubeFace(index: index, side: .right)

      try store.send(to: \.destination?.game, .tap(.began, C)) {
        try $0.destination.modify(\.game) {
          $0.optimisticallySelectedFace = C
          $0.selectedWord = [C]
        }
      }
      try store.send(to: \.destination?.game, .tap(.ended, C)) {
        try $0.destination.modify(\.game) {
          $0.optimisticallySelectedFace = nil
        }
      }
      try store.send(to: \.destination?.game, .tap(.began, A)) {
        try $0.destination.modify(\.game) {
          $0.optimisticallySelectedFace = A
          $0.selectedWord = [C, A]
        }
      }
      try store.send(to: \.destination?.game, .tap(.ended, A)) {
        try $0.destination.modify(\.game) {
          $0.optimisticallySelectedFace = nil
        }
      }
      try store.send(to: \.destination?.game, .tap(.began, B)) {
        try $0.destination.modify(\.game) {
          $0.optimisticallySelectedFace = B
          $0.selectedWord = [C, A, B]
          $0.selectedWordIsValid = true
        }
      }
      try store.send(to: \.destination?.game, .tap(.ended, B)) {
        try $0.destination.modify(\.game) {
          $0.optimisticallySelectedFace = nil
        }
      }

      let updatedGameState = update(initialGameState) {
        $0.isGameLoaded = true
        $0.moves = [
          .init(
            playedAt: self.now,
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
      }
      let updatedMatch = update(newMatch) {
        $0.currentParticipant = .remote
        $0.matchData = Data(
          turnBasedMatchData: TurnBasedMatchData(
            context: TurnBasedContext(
              localPlayer: .mock,
              match: newMatch,
              metadata: .init(
                lastOpenedAt: self.now,
                playerIndexToId: [0: currentPlayer.player.id]
              )
            ),
            gameState: updatedGameState,
            playerId: currentPlayer.player.id
          )
        )
      }
      loadedMatch.withValue { [updatedMatch] in $0 = updatedMatch }

      await store.send(to: \.destination?.game, .submitButtonTapped(reaction: .angel)) {
        $0.destination = .game(snap(updatedGameState))
      }?.value
      expectNoDifference(
        didEndTurnWithRequest.value,
        .init(
          for: newMatch.matchId,
          matchData: Data(
            turnBasedMatchData: TurnBasedMatchData(
              context: try XCTUnwrap(updatedGameState.gameContext.turnBased),
              gameState: updatedGameState,
              playerId: currentPlayer.player.id
            )
          ),
          message: "Blob played CAB! (+27 😇)"
        )
      )

      try store.expect {
        try $0.destination.modify(\.game) {
          $0.gameContext = .turnBased(
            .init(
              localPlayer: .mock,
              match: updatedMatch,
              metadata: .init(
                lastOpenedAt: self.now,
                playerIndexToId: [0: currentPlayer.player.id]
              )
            )
          )
        }
      }

      await store.dismount()
    }
  }

  func testResumeGame() async throws {
    await withMainSerialExecutor {
      let listener = AsyncStreamProducer<LocalPlayerClient.ListenerEvent>()

      let dailyChallenges = [
        FetchTodaysDailyChallengeResponse(
          dailyChallenge: .init(
            endsAt: self.now,
            gameMode: .unlimited,
            id: .init(rawValue: .dailyChallengeId),
            language: .en
          ),
          yourResult: .init(outOf: 0, rank: nil, score: nil)
        ),
        FetchTodaysDailyChallengeResponse(
          dailyChallenge: .init(
            endsAt: self.now,
            gameMode: .timed,
            id: .init(rawValue: .dailyChallengeId),
            language: .en
          ),
          yourResult: .init(outOf: 0, rank: nil, score: nil)
        ),
      ]
      let weekInReview = FetchWeekInReviewResponse(ranks: [], word: nil)

      let store = withDependencies {
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
        $0.fileClient.save = { @Sendable _, _ in }
        $0.gameCenter.localPlayer.listener = { listener.stream }
        $0.gameCenter.localPlayer.localPlayer = { .mock }
        $0.gameCenter.turnBasedMatch.saveCurrentTurn = { _, _ in }
        $0.gameCenter.turnBasedMatchmakerViewController.dismiss = {}
      } operation: {
        TestStore(initialState: AppReducer.State()) {
          AppReducer()
            .environment(\.continuousClock, self.clock)
        }
      }

      await Task.megaYield()
      store.expect {
        $0.home.hasChangelog = true
        $0.home.dailyChallenges = dailyChallenges
        $0.home.weekInReview = weekInReview
      }

      listener.continuation
        .yield(.turnBased(.receivedTurnEventForMatch(.inProgress, didBecomeActive: true)))
      await Task.megaYield()

      store.expect {
        $0.destination = .game(
          snap(
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
            ) {
              $0.gameCurrentTime = self.now
              $0.isGameLoaded = true
            }
          )
        )
      }

      await store.dismount()
    }
  }

  func testResumeForfeitedGame() async throws {
    await withMainSerialExecutor {
      let listener = AsyncStreamProducer<LocalPlayerClient.ListenerEvent>()

      let dailyChallenges = [
        FetchTodaysDailyChallengeResponse(
          dailyChallenge: .init(
            endsAt: self.now,
            gameMode: .unlimited,
            id: .init(rawValue: .dailyChallengeId),
            language: .en
          ),
          yourResult: .init(outOf: 0, rank: nil, score: nil)
        ),
        FetchTodaysDailyChallengeResponse(
          dailyChallenge: .init(
            endsAt: self.now,
            gameMode: .timed,
            id: .init(rawValue: .dailyChallengeId),
            language: .en
          ),
          yourResult: .init(outOf: 0, rank: nil, score: nil)
        ),
      ]
      let weekInReview = FetchWeekInReviewResponse(ranks: [], word: nil)
      let index = LatticePoint(x: .two, y: .two, z: .two)
      let turnBasedMatchData = TurnBasedMatchData(
        cubes: .mock,
        gameMode: .unlimited,
        language: .en,
        metadata: .init(lastOpenedAt: nil, playerIndexToId: [:]),
        moves: [
          .init(
            playedAt: .mock,
            playerIndex: 0,
            reactions: nil,
            score: 27,
            type: .playedWord([
              IndexedCubeFace(index: index, side: .top),
              IndexedCubeFace(index: index, side: .left),
              IndexedCubeFace(index: index, side: .right),
            ])
          )
        ]
      )
      let forfeitedMatch = update(TurnBasedMatch.forfeited) {
        $0.matchData = Data(turnBasedMatchData: turnBasedMatchData)
      }

      let store = withDependencies {
        $0.didFinishLaunching()
        $0.apiClient.authenticate = { _ in .mock }
        $0.apiClient.currentPlayer = { nil }
        $0.apiClient.apiRequest = { @Sendable route in
          switch route {
          case .dailyChallenge(.today):
            return try (JSONEncoder().encode(dailyChallenges), .init())
          case .games(.submit):
            return try (JSONEncoder().encode(SubmitGameResponse.turnBased), .init())
          case .leaderboard(.weekInReview):
            return try (JSONEncoder().encode(weekInReview), .init())
          default:
            return try await Task.never()
          }
        }
        $0.build.number = { 42 }
        $0.fileClient.save = { @Sendable _, _ in }
        $0.gameCenter.localPlayer.listener = { listener.stream }
        $0.gameCenter.localPlayer.localPlayer = { .mock }
        $0.gameCenter.turnBasedMatchmakerViewController.dismiss = {}
      } operation: {
        TestStore(initialState: AppReducer.State()) {
          AppReducer()
            .environment(\.continuousClock, self.clock)
        }
      }

      await Task.megaYield()
      store.expect {
        $0.home.hasChangelog = true
        $0.home.dailyChallenges = dailyChallenges
        $0.home.weekInReview = weekInReview
      }

      listener.continuation
        .yield(.turnBased(.receivedTurnEventForMatch(forfeitedMatch, didBecomeActive: true)))
      await Task.megaYield()

      var gameState = Game.State(
        gameCurrentTime: self.now,
        localPlayer: .mock,
        turnBasedMatch: forfeitedMatch,
        turnBasedMatchData: turnBasedMatchData
      )
      gameState.destination = .gameOver(
        GameOver.State(
          completedGame: CompletedGame(gameState: gameState),
          isDemo: false,
          turnBasedContext: .init(
            localPlayer: .mock,
            match: forfeitedMatch,
            metadata: .init(lastOpenedAt: nil, playerIndexToId: [:])
          ),
          userNotificationSettings: .init(authorizationStatus: .notDetermined)
        )
      )
      store.expect {
        $0.destination = .game(snap(gameState))
      }

      await store.dismount()
    }
  }

  func testRemovingCubes() async throws {
    let didEndTurnWithRequest = LockIsolated<TurnBasedMatchClient.EndTurnRequest?>(nil)
    let loadedMatch = LockIsolated<TurnBasedMatch?>(nil)
    let match = update(TurnBasedMatch.inProgress) {
      $0.creationDate = self.now.addingTimeInterval(-60*5)
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
      gameCurrentTime: self.now,
      gameMode: .unlimited,
      gameStartTime: match.creationDate,
      secondsPlayed: 0
    )
    let store = withDependencies {
      $0.didFinishLaunching()
      $0.apiClient.currentPlayer = { nil }
      $0.gameCenter.localPlayer.localPlayer = { .mock }
      $0.gameCenter.turnBasedMatch.endTurn = { didEndTurnWithRequest.setValue($0) }
      $0.gameCenter.turnBasedMatch.load = { _ in try XCTUnwrap(loadedMatch.value) }
      $0.gameCenter.turnBasedMatch.saveCurrentTurn = { _, _ in }
    } operation: {
      TestStore(
        initialState: AppReducer.State(destination: .game(initialGameState))
      ) {
        AppReducer()
          .environment(\.continuousClock, self.clock)
      }
    }

    try store.send(to: \.destination?.game, .doubleTap(index: .zero)) {
      try $0.destination.modify(\.game) {
        $0.destination = .bottomMenu(
          snap(
            BottomMenuState.removeCube(
              index: .zero,
              state: initialGameState,
              isTurnEndingRemoval: false
            )
          )
        )
      }
    }

    var updatedGameState = update(initialGameState) {
      $0.destination = nil
      $0.cubes.0.0.0.wasRemoved = true
      $0.moves.append(
        .init(
          playedAt: self.now,
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
    loadedMatch.withValue { [updatedMatch] in $0 = updatedMatch }

    await store.send(to: \.destination?.game, .destination(.bottomMenu(.confirmRemoveCube(.zero)))) {
      $0.destination = .game(snap(updatedGameState))
    }?.value
    try store.expect {
      try $0.destination.modify(\.game) {
        $0.gameContext = .turnBased(
          .init(
            localPlayer: .mock,
            match: updatedMatch,
            metadata: .init(lastOpenedAt: nil, playerIndexToId: [:])
          )
        )
      }
    }
    let game = try XCTUnwrap(store.state.destination?.game)
    try store.send(to: \.destination?.game, .doubleTap(index: .init(x: .zero, y: .zero, z: .one))) {
      try $0.destination.modify(\.game) {
        $0.destination = .bottomMenu(
          snap(
            BottomMenuState.removeCube(
              index: .init(x: .zero, y: .zero, z: .one),
              state: game,
              isTurnEndingRemoval: true
            )
          )
        )
      }
    }

    updatedGameState = try update(updatedGameState) {
      $0.moves.append(
        .init(
          playedAt: self.now,
          playerIndex: 0,
          reactions: nil,
          score: 0,
          type: .removedCube(.init(x: .zero, y: .zero, z: .one))
        )
      )
      try $0.gameContext.modify(\.turnBased) { $0.match = updatedMatch }
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
    loadedMatch.withValue { [updatedMatch] in $0 = updatedMatch }

    await store.send(
      to: \.destination?.game,
      .destination(.bottomMenu(.confirmRemoveCube(.init(x: .zero, y: .zero, z: .one))))
    ) {
      $0.destination = .game(snap(updatedGameState))
    }?.value
    try store.expect {
      try $0.destination.modify(\.game) {
        $0.gameContext = .turnBased(
          .init(
            localPlayer: .mock,
            match: updatedMatch,
            metadata: .init(lastOpenedAt: nil, playerIndexToId: [:])
          )
        )
      }
    }
    store.send(to: \.destination?.game, .doubleTap(index: .init(x: .zero, y: .zero, z: .two)))

    expectNoDifference(
      didEndTurnWithRequest.value,
      .init(
        for: match.matchId,
        matchData: Data(
          turnBasedMatchData: TurnBasedMatchData(
            context: try XCTUnwrap(updatedGameState.gameContext.turnBased),
            gameState: updatedGameState,
            playerId: nil
          )
        ),
        message: "Blob removed cubes!"
      )
    )

    await store.dismount()
  }

  func testRematch() async throws {
    try await withMainSerialExecutor {
      let localParticipant = TurnBasedParticipant.local
      let match = update(TurnBasedMatch.inProgress) {
        $0.currentParticipant = localParticipant
        $0.creationDate = self.now.addingTimeInterval(-60*5)
        $0.participants = [localParticipant, .remote]
      }
      let didRematchWithId = LockIsolated<TurnBasedMatch.Id?>(nil)

      let newMatch = update(TurnBasedMatch.new) { $0.creationDate = self.now }

      let index = LatticePoint(x: .two, y: .two, z: .two)
      let game = update(
        Game.State(
          cubes: .mock,
          gameContext: .turnBased(
            .init(
              localPlayer: .mock,
              match: match,
              metadata: .init(lastOpenedAt: nil, playerIndexToId: [:])
            )
          ),
          gameCurrentTime: self.now,
          gameMode: .unlimited,
          gameStartTime: .mock,
          moves: [
            .init(
              playedAt: .mock,
              playerIndex: 0,
              reactions: nil,
              score: 27,
              type: .playedWord([
                IndexedCubeFace(index: index, side: .top),
                IndexedCubeFace(index: index, side: .left),
                IndexedCubeFace(index: index, side: .right),
              ])
            )
          ]
        )
      ) {
        $0.destination = .gameOver(
          GameOver.State(
            completedGame: CompletedGame(gameState: $0),
            isDemo: false
          )
        )
      }

      let store = withDependencies {
        $0.didFinishLaunching()
        $0.apiClient.apiRequest = { @Sendable route in
          switch route {
          case .games(.submit):
            return try (JSONEncoder().encode(SubmitGameResponse.turnBased), .init())
          default:
            return try await Task.never()
          }
        }
        $0.apiClient.currentPlayer = { nil }
        $0.dictionary.randomCubes = { _ in .mock }
        $0.gameCenter.localPlayer.localPlayer = {
          update(.authenticated) { $0.player = localParticipant.player! }
        }
        $0.gameCenter.turnBasedMatch.rematch = {
          didRematchWithId.setValue($0)
          return newMatch
        }
        $0.gameCenter.turnBasedMatch.saveCurrentTurn = { _, _ in }
        $0.gameCenter.turnBasedMatchmakerViewController.dismiss = {}
      } operation: {
        TestStore(initialState: AppReducer.State(destination: .game(game))) {
          AppReducer()
            .environment(\.continuousClock, self.clock)
        }
      }

      await Task.megaYield()
      try store.expect {
        try $0.destination.modify(\.game) {
          $0.destination = .gameOver(
            snap(
              GameOver.State(
                completedGame: CompletedGame(gameState: game),
                isDemo: false,
                userNotificationSettings: .init(authorizationStatus: .notDetermined)
              )
            )
          )
        }
      }

      store.send(to: \.destination?.game, .destination(.gameOver(.rematchButtonTapped))) {
        $0.destination = nil
      }
      await Task.megaYield()
      expectNoDifference(didRematchWithId.value, match.matchId)

      store.expect {
        $0.destination = .game(
          snap(
            Game.State(
              cubes: .mock,
              gameContext: .turnBased(
                .init(
                  localPlayer: .mock,
                  match: newMatch,
                  metadata: .init(lastOpenedAt: self.now, playerIndexToId: [:])
                )
              ),
              gameCurrentTime: self.now,
              gameMode: .unlimited,
              gameStartTime: newMatch.creationDate
            )
          )
        )
      }

      await store.dismount()
    }
  }

  func testGameCenterNotification_ShowsRecentTurn() async throws {
    await withMainSerialExecutor {
      let localParticipant = TurnBasedParticipant.local
      let remoteParticipant = update(TurnBasedParticipant.remote) {
        $0.lastTurnDate = self.now - 10
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

      let notificationBannerRequest = LockIsolated<GameCenterClient.NotificationBannerRequest?>(
        nil
      )
      let listener = AsyncStreamProducer<LocalPlayerClient.ListenerEvent>()

      let store = withDependencies {
        $0.didFinishLaunching()
        $0.gameCenter.localPlayer.listener = { listener.stream }
        $0.gameCenter.localPlayer.localPlayer = { .authenticated }
        $0.gameCenter.showNotificationBanner = { notificationBannerRequest.setValue($0) }
      } operation: {
        TestStore(initialState: AppReducer.State()) {
          AppReducer()
            .environment(\.continuousClock, self.clock)
        }
      }

      listener.continuation.yield(
        .turnBased(.receivedTurnEventForMatch(match, didBecomeActive: false))
      )

      await self.clock.advance()
      await Task.megaYield()
      expectNoDifference(
        notificationBannerRequest.value,
        GameCenterClient.NotificationBannerRequest(
          title: "Blob played ABC!",
          message: nil
        )
      )

      await store.dismount()
    }
  }

  func testGameCenterNotification_DoesNotShow() async throws {
    await withMainSerialExecutor {
      let localParticipant = TurnBasedParticipant.local
      let remoteParticipant = update(TurnBasedParticipant.remote) {
        $0.lastTurnDate = self.now - 10
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

      let listener = AsyncStreamProducer<LocalPlayerClient.ListenerEvent>()

      let store = withDependencies {
        $0.didFinishLaunching()
        $0.gameCenter.localPlayer.listener = { listener.stream }
        $0.gameCenter.localPlayer.localPlayer = { .authenticated }
      } operation: {
        TestStore(initialState: AppReducer.State()) {
          AppReducer()
            .environment(\.continuousClock, self.clock)
        }
      }

      listener.continuation.yield(
        .turnBased(.receivedTurnEventForMatch(match, didBecomeActive: false))
      )
      await self.clock.run()
      await Task.megaYield()

      await store.dismount()
    }
  }
}
