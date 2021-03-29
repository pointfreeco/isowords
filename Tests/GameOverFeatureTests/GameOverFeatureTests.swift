import ComposableArchitecture
import GameOverFeature
import Overture
import SharedModels
import TestHelpers
import XCTest

@testable import LocalDatabaseClient
@testable import UserDefaultsClient

class GameOverFeatureTests: XCTestCase {
  let mainRunLoop = RunLoop.testScheduler

  func testSubmitLeaderboardScore() throws {
    let environment = update(GameOverEnvironment.failing) {
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
        withResponse: .ok([
          "solo": [
            "ranks": [
              "lastDay": LeaderboardScoreResult.Rank(outOf: 100, rank: 1),
              "lastWeek": .init(outOf: 1000, rank: 10),
              "allTime": .init(outOf: 10000, rank: 100),
            ]
          ]
        ])
      )
      $0.database.playedGamesCount = { _ in .init(value: 10) }
      $0.mainRunLoop = RunLoop.immediateScheduler.eraseToAnyScheduler()
      $0.mainQueue = DispatchQueue.immediateScheduler.eraseToAnyScheduler()
      $0.serverConfig.config = { .init() }
      $0.userNotifications.getNotificationSettings = .none
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

    store.send(.onAppear)
    store.receive(.enableView)
    store.receive(
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
  }

  func testSubmitDailyChallenge() throws {
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

    var environment = GameOverEnvironment.failing
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
      withResponse: .ok([
        "dailyChallenge": ["rank": 2, "outOf": 100, "score": 1000, "started": true]
      ])
    )
    environment.apiClient.override(
      route: .dailyChallenge(.today(language: .en)),
      withResponse: .ok([
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
    )
    environment.database.playedGamesCount = { _ in .init(value: 10) }
    environment.mainRunLoop = RunLoop.immediateScheduler.eraseToAnyScheduler()
    environment.mainQueue = DispatchQueue.immediateScheduler.eraseToAnyScheduler()
    environment.serverConfig.config = { .init() }
    environment.userNotifications.getNotificationSettings = .none

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

    store.send(.onAppear)
    store.receive(.enableView)
    store.receive(
      .submitGameResponse(
        .success(
          .dailyChallenge(
            .init(outOf: 100, rank: 2, score: 1000, started: true)
          )
        )
      )
    ) {
      $0.summary = .dailyChallenge(.init(outOf: 100, rank: 2, score: 1000, started: true))
    }
    store.receive(
      .dailyChallengeResponse(.success(dailyChallengeResponses))
    ) {
      $0.dailyChallenges = dailyChallengeResponses
    }
  }

  func testTurnBased_TrackLeaderboards() throws {
    var environment = GameOverEnvironment.failing
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
      withResponse: .ok(["turnBased": true])
    )
    environment.database.playedGamesCount = { _ in .init(value: 10) }
    environment.database.fetchStats = .init(
      value: .init(
        averageWordLength: nil,
        gamesPlayed: 1,
        highestScoringWord: nil,
        longestWord: nil,
        secondsPlayed: 1,
        wordsFound: 1
      )
    )
    environment.mainRunLoop = RunLoop.immediateScheduler.eraseToAnyScheduler()
    environment.mainQueue = DispatchQueue.immediateScheduler.eraseToAnyScheduler()
    environment.serverConfig.config = { .init() }
    environment.userNotifications.getNotificationSettings = .none

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

    store.send(.onAppear)
    store.receive(.enableView)
    store.receive(.submitGameResponse(.success(.turnBased)))
  }

  func testRequestReviewOnClose() {
    var lastReviewRequestTimeIntervalSet: Double?
    var requestReviewCount = 0

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

    var environment = GameOverEnvironment.failing
    environment.database.fetchStats = .init(
      value: .init(
        averageWordLength: nil,
        gamesPlayed: 1,
        highestScoringWord: nil,
        longestWord: nil,
        secondsPlayed: 1,
        wordsFound: 1
      )
    )
    environment.mainRunLoop = self.mainRunLoop.eraseToAnyScheduler()
    environment.storeKit.requestReview = {
      .fireAndForget { requestReviewCount += 1 }
    }
    environment.userDefaults.override(0, forKey: "last-review-request-timeinterval")
    environment.userDefaults.setDouble = { double, key in
      .fireAndForget {
        if key == "last-review-request-timeinterval" {
          lastReviewRequestTimeIntervalSet = double
        }
      }
    }
    environment.userNotifications.getNotificationSettings = .none

    let store = TestStore(
      initialState: GameOverState(completedGame: completedGame, isDemo: false, isViewEnabled: true),
      reducer: gameOverReducer,
      environment: environment
    )

    // Assert that the first time game over appears we do not request review
    store.send(.closeButtonTapped)
    store.receive(.delegate(.close))
    self.mainRunLoop.advance()
    XCTAssertEqual(requestReviewCount, 0)
    XCTAssertEqual(lastReviewRequestTimeIntervalSet, nil)

    // Assert that once the player plays enough games then a review request is made
    store.environment.database.fetchStats = .init(
      value: .init(
        averageWordLength: nil,
        gamesPlayed: 3,
        highestScoringWord: nil,
        longestWord: nil,
        secondsPlayed: 1,
        wordsFound: 1
      )
    )
    store.send(.closeButtonTapped)
    store.receive(.delegate(.close))
    self.mainRunLoop.advance()
    XCTAssertEqual(requestReviewCount, 1)
    XCTAssertEqual(lastReviewRequestTimeIntervalSet, 0)

    // Assert that when more than a week of time passes we again request review
    self.mainRunLoop.advance(by: .seconds(60 * 60 * 24 * 7))
    store.send(.closeButtonTapped)
    store.receive(.delegate(.close))
    self.mainRunLoop.advance()
    XCTAssertEqual(requestReviewCount, 2)
    XCTAssertEqual(lastReviewRequestTimeIntervalSet, 60 * 60 * 24 * 7)
  }

  func testAutoCloseWhenNoWordsPlayed() throws {
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
      environment: .failing
    )

    store.send(.onAppear)
    store.receive(.delegate(.close))
  }

  func testShowUpgradeInterstitial() {
    var environment = GameOverEnvironment.failing
    environment.audioPlayer = .noop
    environment.apiClient.currentPlayer = { .init(appleReceipt: nil, player: .blob) }
    environment.apiClient.apiRequest = { route in
      switch route {
      case .games(.submit):
        return .none
      default:
        XCTFail("Unhandled route: \(route)")
        return .none
      }
    }
    environment.database.playedGamesCount = { _ in .init(value: 6) }
    environment.database.fetchStats = .init(value: .init())
    environment.mainRunLoop = self.mainRunLoop.eraseToAnyScheduler()
    environment.mainQueue = DispatchQueue.immediateScheduler.eraseToAnyScheduler()
    environment.serverConfig.config = { .init() }
    environment.userDefaults.override(
      self.mainRunLoop.now.date.timeIntervalSince1970, forKey: "last-review-request-timeinterval"
    )
    environment.userNotifications.getNotificationSettings = .none

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
      environment: environment
    )

    store.send(.onAppear)
    store.receive(.enableView)
    self.mainRunLoop.advance(by: .seconds(1))
    store.receive(.delayedShowUpgradeInterstitial) {
      $0.upgradeInterstitial = .init()
    }
  }

  func testSkipUpgradeIfLessThan10GamesPlayed() {
    var environment = GameOverEnvironment.failing
    environment.audioPlayer = .noop
    environment.apiClient.currentPlayer = { .init(appleReceipt: nil, player: .blob) }
    environment.apiClient.apiRequest = { route in
      switch route {
      case .games(.submit):
        return .none
      default:
        XCTFail("Unhandled route: \(route)")
        return .none
      }
    }
    environment.database.playedGamesCount = { _ in .init(value: 5) }
    environment.database.fetchStats = .init(value: .init())
    environment.mainRunLoop = RunLoop.immediateScheduler.eraseToAnyScheduler()
    environment.mainQueue = DispatchQueue.immediateScheduler.eraseToAnyScheduler()
    environment.serverConfig.config = { .init() }
    environment.userDefaults.override(
      self.mainRunLoop.now.date.timeIntervalSince1970, forKey: "last-review-request-timeinterval"
    )
    environment.userNotifications.getNotificationSettings = .none

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
      environment: environment
    )

    store.send(.onAppear)
    store.receive(.enableView)
  }
}
