import ApiClient
import CasePaths
import ComposableArchitecture
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
    var environment = GameOverEnvironment.unimplemented
    environment.audioPlayer = .noop
    environment.apiClient.currentPlayer = { .init(appleReceipt: .mock, player: .blob) }
    environment.apiClient.override(
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
    environment.database.playedGamesCount = { _ in 0 }
    environment.mainRunLoop = .immediate
    environment.serverConfig.config = { .init() }
    environment.userNotifications.getNotificationSettings = {
      (try? await Task.never()) ?? .init(authorizationStatus: .notDetermined)
    }

    let store = TestStore(
      initialState: GameOverState(
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
      ),
      reducer: gameOverReducer,
      environment: environment
    )

    let task = await store.send(.task)
    await store.receive(
      .submitGameResponse(
        .success(
          .solo(
            .init(ranks: [
              .lastDay: .init(outOf: 100, rank: 1),
              .lastWeek: .init(outOf: 1000, rank: 10),
              .allTime: .init(outOf: 10000, rank: 100),
            ])
          )
        )
      )
    ) {
      $0.summary = .leaderboard([
        .lastDay: .init(outOf: 100, rank: 1),
        .lastWeek: .init(outOf: 1000, rank: 10),
        .allTime: .init(outOf: 10000, rank: 100),
      ])
    }
    await store.receive(.delayedOnAppear) {
      $0.isViewEnabled = true
    }
    await task.cancel()
  }

  func testSubmitDailyChallenge() async throws {
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

    var environment = GameOverEnvironment.unimplemented
    environment.audioPlayer = .noop
    environment.apiClient.currentPlayer = { .init(appleReceipt: .mock, player: .blob) }
    environment.apiClient.override(
      route: .games(
        .submit(
          .init(
            gameContext: .dailyChallenge(.init(rawValue: .dailyChallengeId)),
            moves: [.mock]
          )
        )
      ),
      withResponse: {
        try await OK(["dailyChallenge": ["rank": 2, "outOf": 100, "score": 1000, "started": true]])
      }
    )
    environment.apiClient.override(
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
            "yourResult": ["outOf": 42, "rank": 1, "score": 3600, "started": true],
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
    environment.database.playedGamesCount = { _ in 0 }
    environment.mainRunLoop = .immediate
    environment.serverConfig.config = { .init() }
    environment.userNotifications.getNotificationSettings = {
      (try? await Task.never()) ?? .init(authorizationStatus: .notDetermined)
    }

    let store = TestStore(
      initialState: GameOverState(
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
      ),
      reducer: gameOverReducer,
      environment: environment
    )

    let task = await store.send(.task)
    await store.receive(
      .submitGameResponse(
        .success(.dailyChallenge(.init(outOf: 100, rank: 2, score: 1000, started: true)))
      )
    ) {
      $0.summary = .dailyChallenge(.init(outOf: 100, rank: 2, score: 1000, started: true))
    }
    await store.receive(.delayedOnAppear) { $0.isViewEnabled = true }
    await store.receive(.dailyChallengeResponse(.success(dailyChallengeResponses))) {
      $0.dailyChallenges = dailyChallengeResponses
    }
    await task.cancel()
  }

  func testTurnBased_TrackLeaderboards() async throws {
    var environment = GameOverEnvironment.unimplemented
    environment.audioPlayer = .noop
    environment.apiClient.currentPlayer = { .init(appleReceipt: .mock, player: .blob) }
    environment.apiClient.override(
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
    environment.database.playedGamesCount = { _ in 10 }
    environment.mainRunLoop = .immediate
    environment.serverConfig.config = { .init() }
    environment.userNotifications.getNotificationSettings = {
      (try? await Task.never()) ?? .init(authorizationStatus: .notDetermined)
    }

    let store = TestStore(
      initialState: GameOverState(
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
      ),
      reducer: gameOverReducer,
      environment: environment
    )

    let task = await store.send(.task)
    await store.receive(.submitGameResponse(.success(.turnBased)))
    await store.receive(.delayedOnAppear) { $0.isViewEnabled = true }
    await task.cancel()
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

    var environment = GameOverEnvironment.unimplemented
    environment.database.fetchStats = {
      LocalDatabaseClient.Stats(
        averageWordLength: nil,
        gamesPlayed: 1,
        highestScoringWord: nil,
        longestWord: nil,
        secondsPlayed: 1,
        wordsFound: 1
      )
    }
    environment.mainRunLoop = self.mainRunLoop.eraseToAnyScheduler()
    environment.storeKit.requestReview = {
      await requestReviewCount.withValue { $0 += 1 }
    }
    environment.userDefaults.override(double: 0, forKey: "last-review-request-timeinterval")
    environment.userDefaults.setDouble = { double, key in
      if key == "last-review-request-timeinterval" {
        await lastReviewRequestTimeIntervalSet.setValue(double)
      }
    }

    let store = TestStore(
      initialState: GameOverState(completedGame: completedGame, isDemo: false, isViewEnabled: true),
      reducer: gameOverReducer,
      environment: environment
    )

    // Assert that the first time game over appears we do not request review
    await store.send(.closeButtonTapped)
    await store.receive(.delegate(.close))
    await self.mainRunLoop.advance()
    await requestReviewCount.withValue { XCTAssertNoDifference($0, 0) }
    await lastReviewRequestTimeIntervalSet.withValue { XCTAssertNoDifference($0, nil) }

    // Assert that once the player plays enough games then a review request is made
    store.environment.database.fetchStats = {
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
    await store.receive(.delegate(.close))
    await requestReviewCount.withValue { XCTAssertNoDifference($0, 1) }
    await lastReviewRequestTimeIntervalSet.withValue { XCTAssertNoDifference($0, 0) }

    // Assert that when more than a week of time passes we again request review
    await self.mainRunLoop.advance(by: .seconds(60 * 60 * 24 * 7))
    await store.send(.closeButtonTapped).finish()
    await store.receive(.delegate(.close))
    await requestReviewCount.withValue { XCTAssertNoDifference($0, 2) }
    await lastReviewRequestTimeIntervalSet.withValue { XCTAssertNoDifference($0, 60 * 60 * 24 * 7) }
  }

  func testAutoCloseWhenNoWordsPlayed() async throws {
    let store = TestStore(
      initialState: GameOverState(
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
      ),
      reducer: gameOverReducer,
      environment: .unimplemented
    )

    await store.send(.task)
    await store.receive(.delegate(.close))
  }

  func testShowUpgradeInterstitial() async {
    let store = TestStore(
      initialState: GameOverState(
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
      ),
      reducer: gameOverReducer,
      environment: .unimplemented
    )

    store.environment.audioPlayer = .noop
    store.environment.apiClient.currentPlayer = { .init(appleReceipt: nil, player: .blob) }
    store.environment.apiClient.apiRequest = { @Sendable _ in try await Task.never() }
    store.environment.database.playedGamesCount = { _ in 6 }
    store.environment.mainRunLoop = .immediate
    store.environment.serverConfig.config = { .init() }
    store.environment.userDefaults.override(double: 0, forKey: "last-review-request-timeinterval")
    store.environment.userNotifications.getNotificationSettings = {
      (try? await Task.never()) ?? .init(authorizationStatus: .notDetermined)
    }

    let task = await store.send(.task)
    await store.receive(.delayedShowUpgradeInterstitial) {
      $0.upgradeInterstitial = .init()
    }
    await store.receive(.delayedOnAppear) { $0.isViewEnabled = true }
    await task.cancel()
  }

  func testSkipUpgradeIfLessThan6GamesPlayed() async {
    let store = TestStore(
      initialState: GameOverState(
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
      ),
      reducer: gameOverReducer,
      environment: .unimplemented
    )

    store.environment.audioPlayer = .noop
    store.environment.apiClient.currentPlayer = { .init(appleReceipt: nil, player: .blob) }
    store.environment.apiClient.apiRequest = { @Sendable _ in try await Task.never() }
    store.environment.database.playedGamesCount = { _ in 5 }
    store.environment.mainRunLoop = .immediate
    store.environment.serverConfig.config = { .init() }
    store.environment.userDefaults.override(double: 0, forKey: "last-review-request-timeinterval")
    store.environment.userNotifications.getNotificationSettings = {
      (try? await Task.never()) ?? .init(authorizationStatus: .notDetermined)
    }

    let task = await store.send(.task)
    await store.receive(.delayedOnAppear) { $0.isViewEnabled = true }
    await task.cancel()
  }
}
