import ApiClient
import CasePaths
import ComposableArchitecture
@_spi(Concurrency) import Dependencies
import ConcurrencyExtras
import CustomDump
import Dependencies
import GameOverFeature
import Overture
import ServerConfig
import SharedModels
import TestHelpers
import XCTest

@testable import LocalDatabaseClient
@testable import UpgradeInterstitialFeature
@testable import UserDefaultsClient

class GameOverFeatureTests: XCTestCase {
  @MainActor
  func testSubmitLeaderboardScore() async throws {
    await withMainSerialExecutor {
      let store = withDependencies {
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
        $0.serverConfig.config = { .init() }
        $0.userNotifications.getNotificationSettings = {
          .init(authorizationStatus: .notDetermined)
        }
      } operation: {
        TestStore(
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
        }
      }

      await store.mountTask?.value
      await store.receive(
        key: GameOver.Event.self,
        value: .matching { $0.is(\.gameSubmitted) }
      ) {
        $0.userNotificationSettings = .init(authorizationStatus: .notDetermined)
        $0.summary = .leaderboard([
          .lastDay: .init(outOf: 100, rank: 1),
          .lastWeek: .init(outOf: 1000, rank: 10),
          .allTime: .init(outOf: 10000, rank: 100),
        ])
      }
      store.expect {
        $0.isViewEnabled = true
      }
    }
  }

  @MainActor
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

      let store = withDependencies {
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
        $0.serverConfig.config = { .init() }
        $0.userNotifications.getNotificationSettings = {
          .init(authorizationStatus: .notDetermined)
        }
      } operation: {
        TestStore(
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
        }
      }

      await store.mountTask?.value
      await store.receive(
        key: GameOver.Event.self,
        value: .matching { $0.is(\.gameSubmitted) }
      ) {
        $0.isViewEnabled = true
        $0.summary = .dailyChallenge(.init(outOf: 100, rank: 2, score: 1000, started: true))
        $0.userNotificationSettings = .init(authorizationStatus: .notDetermined)
      }
      store.expect {
        $0.dailyChallenges = dailyChallengeResponses
      }
    }
  }

  @MainActor
  func testTurnBased_TrackLeaderboards() async {
    await withMainSerialExecutor {
      let store = withDependencies {
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
        $0.serverConfig.config = { .init() }
        $0.userNotifications.getNotificationSettings = {
          .init(authorizationStatus: .notDetermined)
        }
      } operation: {
        TestStore(
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
        }
      }

      await store.mountTask?.value
      await store.receive(
        key: GameOver.Event.self,
        value: .matching { $0[case: \.gameSubmitted]?.is(\.turnBased) == true }
      ) {
        $0.userNotificationSettings = .init(authorizationStatus: .notDetermined)
      }
      store.expect {
        $0.isViewEnabled = true
      }
    }
  }

  @MainActor
  func testRequestReviewOnClose() async {
    let now = LockIsolated(Date(timeIntervalSince1970: 0))
    let lastReviewRequestTimeIntervalSet = ActorIsolated<Double?>(nil)
    let requestReviewCount = ActorIsolated(0)
    let gamesPlayed = LockIsolated(1)

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

    let store = withDependencies {
      $0.apiClient.apiRequest = { @Sendable _ in
        try await OK(["solo": ["ranks": [String: LeaderboardScoreResult.Rank]()]])
      }
      $0.apiClient.currentPlayer = { .init(appleReceipt: .mock, player: .blob) }
      $0.audioPlayer = .noop
      $0.database.fetchStats = {
        LocalDatabaseClient.Stats(
          averageWordLength: nil,
          gamesPlayed: gamesPlayed.value,
          highestScoringWord: nil,
          longestWord: nil,
          secondsPlayed: 1,
          wordsFound: 1
        )
      }
      $0.database.playedGamesCount = { _ in 0 }
      $0.serverConfig.config = { .init() }
      $0.storeKit.requestReview = {
        await requestReviewCount.withValue { $0 += 1 }
      }
      $0.userDefaults.override(double: 0, forKey: "last-review-request-timeinterval")
      $0.userDefaults.setDouble = { double, key in
        if key == "last-review-request-timeinterval" {
          await lastReviewRequestTimeIntervalSet.setValue(double)
        }
      }
      $0.userNotifications.getNotificationSettings = {
        (try? await Task.never()) ?? .init(authorizationStatus: .notDetermined)
      }
    } operation: {
      TestStore(
        initialState: GameOver.State(
          completedGame: completedGame,
          isDemo: false,
          isViewEnabled: true
        )
      ) {
        GameOver()
          .environment(\.date, Dependencies.DateGenerator { now.value })
      }
    }

    await store.receive(
      key: GameOver.Event.self,
      value: .matching { $0.is(\.gameSubmitted) },
      timeout: .seconds(1)
    ) {
      $0.summary = .leaderboard([:])
    }

    // Assert that the first time game over appears we do not request review
    store.send(.closeButtonTapped)
    await store.receive(
      key: GameOver.Event.self,
      value: .matching { $0.is(\.dismissGame) },
      timeout: .seconds(1)
    )
    await requestReviewCount.withValue { expectNoDifference($0, 0) }
    await lastReviewRequestTimeIntervalSet.withValue { expectNoDifference($0, nil) }

    // Assert that once the player plays enough games then a review request is made
    gamesPlayed.setValue(3)
    store.send(.closeButtonTapped)
    await store.receive(
      key: GameOver.Event.self,
      value: .matching { $0.is(\.dismissGame) },
      timeout: .seconds(1)
    )
    await requestReviewCount.withValue { expectNoDifference($0, 1) }
    await lastReviewRequestTimeIntervalSet.withValue { expectNoDifference($0, 0) }

    // Assert that when more than a week of time passes we again request review
    now.withValue { $0.addTimeInterval(60 * 60 * 24 * 7) }
    store.send(.closeButtonTapped)
    await store.receive(
      key: GameOver.Event.self,
      value: .matching { $0.is(\.dismissGame) },
      timeout: .seconds(1)
    )
    await requestReviewCount.withValue { expectNoDifference($0, 2) }
    await lastReviewRequestTimeIntervalSet.withValue { expectNoDifference($0, 60 * 60 * 24 * 7) }

    await store.dismount()
  }

  @MainActor
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
    }

    await store.receive(
      key: GameOver.Event.self,
      value: .matching { $0.is(\.dismissGame) },
      timeout: .seconds(1)
    )
  }

  @MainActor
  func testShowUpgradeInterstitial() async {
    let clock = TestClock<Duration>()
    let store = withDependencies {
      $0.audioPlayer = .noop
      $0.apiClient.currentPlayer = { .init(appleReceipt: nil, player: .blob) }
      $0.apiClient.apiRequest = { @Sendable _ in
        try await OK(["solo": ["ranks": [String: LeaderboardScoreResult.Rank]()]])
      }
      $0.database.playedGamesCount = { _ in 6 }
      $0.serverConfig.config = { .init() }
      $0.storeKit = .noop
      $0.userNotifications.getNotificationSettings = {
        (try? await Task.never()) ?? .init(authorizationStatus: .notDetermined)
      }
    } operation: {
      TestStore(
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
          .environment(\.continuousClock, clock)
      }
    }

    await store.receive(
      key: GameOver.Event.self,
      value: .matching { $0.is(\.gameSubmitted) },
      timeout: .seconds(1)
    ) {
      $0.summary = .leaderboard([:])
    }
    await clock.advance(by: .seconds(1))
    store.expect {
      $0.destination = .upgradeInterstitial(
        UpgradeInterstitial.State.DebugSnapshot(
          fullGameProduct: nil,
          isDismissable: false,
          isPurchasing: false,
          secondsPassedCount: 0,
          upgradeInterstitialDuration: ServerConfig.UpgradeInterstitial.default.duration
        )
      )
    }
    await clock.advance(by: .seconds(1))
    store.expect {
      $0.isViewEnabled = true
      $0.destination = .upgradeInterstitial(
        UpgradeInterstitial.State.DebugSnapshot(
          fullGameProduct: nil,
          isDismissable: false,
          isPurchasing: false,
          secondsPassedCount: 1,
          upgradeInterstitialDuration: ServerConfig.UpgradeInterstitial.default.duration
        )
      )
    }
    await store.dismount()
  }

  @MainActor
  func testSkipUpgradeIfLessThan6GamesPlayed() async {
    let store = withDependencies {
      $0.audioPlayer = .noop
      $0.apiClient.currentPlayer = { .init(appleReceipt: nil, player: .blob) }
      $0.apiClient.apiRequest = { @Sendable _ in
        try await OK(["solo": ["ranks": [String: LeaderboardScoreResult.Rank]()]])
      }
      $0.database.playedGamesCount = { _ in 5 }
      $0.serverConfig.config = { .init() }
      $0.userNotifications.getNotificationSettings = {
        .init(authorizationStatus: .notDetermined)
      }
    } operation: {
      TestStore(
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
      }
    }

    await store.mountTask?.value
    await store.receive(
      key: GameOver.Event.self,
      value: .matching { $0.is(\.gameSubmitted) }
    ) {
      $0.isViewEnabled = true
      $0.summary = .leaderboard([:])
      $0.userNotificationSettings = .init(authorizationStatus: .notDetermined)
    }
  }
}
