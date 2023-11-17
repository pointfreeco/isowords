import ApiClient
import CasePaths
import ComposableArchitecture
@_spi(Concurrency) import Dependencies
import GameOverFeature
import Overture
import SharedModels
import TestHelpers
import XCTest

@testable import LocalDatabaseClient
@testable import UserDefaultsClient

@MainActor
class GameOverFeatureTests: XCTestCase {
  let mainRunLoop = RunLoop.test

  func testSubmitLeaderboardScore() async throws {
    await withMainSerialExecutor {
      let store = TestStore(
        initialState: GameOver.State(
          completedGame: .init(
            cubes: .mock,
            gameContext: .solo,
            gameMode: .timed,
            gameStartTime: .init(timeIntervalSince1970: 1_234_567_890),
            language: .en,
            moves: [.mock],
            secondsPlayed: 0
          ),
          isDemo: false
        )
      ) {
        GameOver()
      } withDependencies: {
        $0.audioPlayer = .noop
        $0.apiClient.currentPlayer = { .init(appleReceipt: .mock, player: .blob) }
        $0.apiClient.override(
          route: .games(
            .submit(
              .init(
                gameContext: .solo(.init(gameMode: .timed, language: .en, puzzle: .mock)),
                moves: [.mock]
              )
            )
          ),
          withResponse: {
            try await OK([
              "solo": [
                "ranks": [
                  "lastDay": LeaderboardScoreResult.Rank(outOf: 100, rank: 1),
                  "lastWeek": .init(outOf: 1000, rank: 10),
                  "allTime": .init(outOf: 10000, rank: 100),
                ]
              ]
            ])
          }
        )
        $0.database.playedGamesCount = { _ in 0 }
        $0.mainRunLoop = .immediate
        $0.serverConfig.config = { .init() }
        $0.userNotifications.getNotificationSettings = {
          (try? await Task.never()) ?? .init(authorizationStatus: .notDetermined)
        }
      }

      let task = await store.send(.task)
      await store.receive(\.delayedOnAppear) {
        $0.isViewEnabled = true
      }
      await store.receive(\.submitGameResponse.success) {
        $0.summary = .leaderboard([
          .lastDay: .init(outOf: 100, rank: 1),
          .lastWeek: .init(outOf: 1000, rank: 10),
          .allTime: .init(outOf: 10000, rank: 100),
        ])
      }
      await task.cancel()
    }
  }

  func testSubmitDailyChallenge() async {
    await withMainSerialExecutor {
      let dailyChallengeResponses = [
        FetchTodaysDailyChallengeResponse(
          dailyChallenge: .init(
            endsAt: .mock,
            gameMode: .timed,
            id: .init(rawValue: .dailyChallengeId),
            language: .en
          ),
          yourResult: .init(outOf: 42, rank: 1, score: 3600, started: true)
        ),
        FetchTodaysDailyChallengeResponse(
          dailyChallenge: .init(
            endsAt: .mock,
            gameMode: .unlimited,
            id: .init(rawValue: .dailyChallengeId),
            language: .en
          ),
          yourResult: .init(outOf: 42, rank: nil, score: nil)
        ),
      ]

      let store = TestStore(
        initialState: GameOver.State(
          completedGame: .init(
            cubes: .mock,
            gameContext: .dailyChallenge(.init(rawValue: .dailyChallengeId)),
            gameMode: .timed,
            gameStartTime: .init(timeIntervalSince1970: 1_234_567_890),
            language: .en,
            moves: [.mock],
            secondsPlayed: 0
          ),
          isDemo: false
        )
      ) {
        GameOver()
      } withDependencies: {
        $0.audioPlayer = .noop
        $0.apiClient.currentPlayer = { .init(appleReceipt: .mock, player: .blob) }
        $0.apiClient.override(
          route: .games(
            .submit(
              .init(
                gameContext: .dailyChallenge(.init(rawValue: .dailyChallengeId)),
                moves: [.mock]
              )
            )
          ),
          withResponse: {
            try await OK([
              "dailyChallenge": [
                "rank": 2, "outOf": 100, "score": 1000, "started": true
              ] as [String : Any]
            ])
          }
        )
        $0.apiClient.override(
          route: .dailyChallenge(.today(language: .en)),
          withResponse: {
            try await OK([
              [
                "dailyChallenge": [
                  "endsAt": 1_234_567_890,
                  "gameMode": "timed",
                  "id": UUID.dailyChallengeId.uuidString,
                  "language": "en",
                ],
                "yourResult": [
                  "outOf": 42, "rank": 1, "score": 3600, "started": true
                ] as [String : Any],
              ],
              [
                "dailyChallenge": [
                  "endsAt": 1_234_567_890,
                  "gameMode": "unlimited",
                  "id": UUID.dailyChallengeId.uuidString,
                  "language": "en",
                ],
                "yourResult": ["outOf": 42, "started": false],
              ],
            ])
          }
        )
        $0.database.playedGamesCount = { _ in 0 }
        $0.mainRunLoop = .immediate
        $0.serverConfig.config = { .init() }
        $0.userNotifications.getNotificationSettings = {
          (try? await Task.never()) ?? .init(authorizationStatus: .notDetermined)
        }
      }

      let task = await store.send(.task)
      await store.receive(\.delayedOnAppear) { $0.isViewEnabled = true }
      await store.receive(\.submitGameResponse.success) {
        $0.summary = .dailyChallenge(.init(outOf: 100, rank: 2, score: 1000, started: true))
      }
      await store.receive(\.dailyChallengeResponse.success) {
        $0.dailyChallenges = dailyChallengeResponses
      }
      await task.cancel()
    }
  }

  func testTurnBased_TrackLeaderboards() async {
    await withMainSerialExecutor {
      let store = TestStore(
        initialState: GameOver.State(
          completedGame: .init(
            cubes: .mock,
            gameContext: .turnBased(playerIndexToId: [0: .init(rawValue: .deadbeef)]),
            gameMode: .unlimited,
            gameStartTime: .mock,
            language: .en,
            localPlayerIndex: 1,
            moves: [.mock],
            secondsPlayed: 0
          ),
          isDemo: false
        )
      ) {
        GameOver()
      } withDependencies: {
        $0.audioPlayer = .noop
        $0.apiClient.currentPlayer = { .init(appleReceipt: .mock, player: .blob) }
        $0.apiClient.override(
          route: .games(
            .submit(
              .init(
                gameContext: .turnBased(
                  .init(
                    gameMode: .unlimited,
                    language: .en,
                    playerIndexToId: [0: .init(rawValue: .deadbeef)],
                    puzzle: .mock
                  )
                ),
                moves: [.mock]
              )
            )
          ),
          withResponse: { try await OK(["turnBased": true]) }
        )
        $0.database.playedGamesCount = { _ in 10 }
        $0.mainRunLoop = .immediate
        $0.serverConfig.config = { .init() }
        $0.userNotifications.getNotificationSettings = {
          (try? await Task.never()) ?? .init(authorizationStatus: .notDetermined)
        }
      }

      let task = await store.send(.task)
      await store.receive(\.delayedOnAppear) { $0.isViewEnabled = true }
      await store.receive(\.submitGameResponse.success.turnBased)
      await task.cancel()
    }
  }

  func testRequestReviewOnClose() async {
    let lastReviewRequestTimeIntervalSet = ActorIsolated<Double?>(nil)
    let requestReviewCount = ActorIsolated(0)
    
    let completedGame = CompletedGame(
      cubes: .mock,
      gameContext: .solo,
      gameMode: .unlimited,
      gameStartTime: .mock,
      language: .en,
      localPlayerIndex: nil,
      moves: [.mock],
      secondsPlayed: 0
    )
    
    let store = TestStore(
      initialState: GameOver.State(
        completedGame: completedGame,
        isDemo: false,
        isViewEnabled: true
      )
    ) {
      GameOver()
    } withDependencies: {
      $0.database.fetchStats = {
        LocalDatabaseClient.Stats(
          averageWordLength: nil,
          gamesPlayed: 1,
          highestScoringWord: nil,
          longestWord: nil,
          secondsPlayed: 1,
          wordsFound: 1
        )
      }
      $0.mainRunLoop = self.mainRunLoop.eraseToAnyScheduler()
      $0.storeKit.requestReview = {
        await requestReviewCount.withValue { $0 += 1 }
      }
      $0.userDefaults.override(double: 0, forKey: "last-review-request-timeinterval")
      $0.userDefaults.setDouble = { double, key in
        if key == "last-review-request-timeinterval" {
          await lastReviewRequestTimeIntervalSet.setValue(double)
        }
      }
      $0.dismiss = DismissEffect {}
    }

    // Assert that the first time game over appears we do not request review
    await store.send(.closeButtonTapped)
    await self.mainRunLoop.advance()
    await requestReviewCount.withValue { XCTAssertNoDifference($0, 0) }
    await lastReviewRequestTimeIntervalSet.withValue { XCTAssertNoDifference($0, nil) }

    // Assert that once the player plays enough games then a review request is made
    store.dependencies.database.fetchStats = {
      .init(
        averageWordLength: nil,
        gamesPlayed: 3,
        highestScoringWord: nil,
        longestWord: nil,
        secondsPlayed: 1,
        wordsFound: 1
      )
    }
    await store.send(.closeButtonTapped).finish()
    await requestReviewCount.withValue { XCTAssertNoDifference($0, 1) }
    await lastReviewRequestTimeIntervalSet.withValue { XCTAssertNoDifference($0, 0) }

    // Assert that when more than a week of time passes we again request review
    await self.mainRunLoop.advance(by: .seconds(60 * 60 * 24 * 7))
    await store.send(.closeButtonTapped).finish()
    await requestReviewCount.withValue { XCTAssertNoDifference($0, 2) }
    await lastReviewRequestTimeIntervalSet.withValue { XCTAssertNoDifference($0, 60 * 60 * 24 * 7) }
  }

  func testAutoCloseWhenNoWordsPlayed() async throws {
    let store = TestStore(
      initialState: GameOver.State(
        completedGame: .init(
          cubes: .mock,
          gameContext: .solo,
          gameMode: .timed,
          gameStartTime: .init(timeIntervalSince1970: 1_234_567_890),
          language: .en,
          moves: [.removeCube],
          secondsPlayed: 0
        ),
        isDemo: false
      )
    ) {
      GameOver()
    } withDependencies: {
      $0.dismiss = DismissEffect {}
    }

    await store.send(.task)
  }

  func testShowUpgradeInterstitial() async {
    let store = TestStore(
      initialState: GameOver.State(
        completedGame: .init(
          cubes: .mock,
          gameContext: .solo,
          gameMode: .timed,
          gameStartTime: .init(timeIntervalSince1970: 1_234_567_890),
          language: .en,
          moves: [.highScoringMove],
          secondsPlayed: 0
        ),
        isDemo: false
      )
    ) {
      GameOver()
    } withDependencies: {
      $0.audioPlayer = .noop
      $0.apiClient.currentPlayer = { .init(appleReceipt: nil, player: .blob) }
      $0.apiClient.apiRequest = { @Sendable _ in try await Task.never() }
      $0.database.playedGamesCount = { _ in 6 }
      $0.mainRunLoop = self.mainRunLoop.eraseToAnyScheduler()
      $0.serverConfig.config = { .init() }
      $0.userNotifications.getNotificationSettings = {
        (try? await Task.never()) ?? .init(authorizationStatus: .notDetermined)
      }
    }

    let task = await store.send(.task)
    await self.mainRunLoop.advance(by: .seconds(1))
    await store.receive(\.delayedShowUpgradeInterstitial) {
      $0.destination = .upgradeInterstitial()
    }
    await self.mainRunLoop.advance(by: .seconds(1))
    await store.receive(\.delayedOnAppear) { $0.isViewEnabled = true }
    await task.cancel()
  }

  func testSkipUpgradeIfLessThan6GamesPlayed() async {
    let store = TestStore(
      initialState: GameOver.State(
        completedGame: .init(
          cubes: .mock,
          gameContext: .solo,
          gameMode: .timed,
          gameStartTime: .init(timeIntervalSince1970: 1_234_567_890),
          language: .en,
          moves: [.highScoringMove],
          secondsPlayed: 0
        ),
        isDemo: false
      )
    ) {
      GameOver()
    } withDependencies: {
      $0.audioPlayer = .noop
      $0.apiClient.currentPlayer = { .init(appleReceipt: nil, player: .blob) }
      $0.apiClient.apiRequest = { @Sendable _ in try await Task.never() }
      $0.database.playedGamesCount = { _ in 5 }
      $0.mainRunLoop = .immediate
      $0.serverConfig.config = { .init() }
      $0.userNotifications.getNotificationSettings = {
        (try? await Task.never()) ?? .init(authorizationStatus: .notDetermined)
      }
    }

    let task = await store.send(.task)
    await store.receive(\.delayedOnAppear) { $0.isViewEnabled = true }
    await task.cancel()
  }
}
