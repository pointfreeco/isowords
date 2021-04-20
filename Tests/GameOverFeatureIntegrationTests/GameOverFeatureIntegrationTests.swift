import ComposableArchitecture
import DatabaseClient
import GameOverFeature
import IntegrationTestHelpers
import SharedModels
import SiteMiddleware
import XCTest

class GameOverFeatureIntegrationTests: XCTestCase {
  let mainRunLoop = RunLoop.test

  func testSubmitSoloScore() {
    let ranks: [TimeScope: LeaderboardScoreResult.Rank] = [
      .allTime: .init(outOf: 100, rank: 10000),
      .lastWeek: .init(outOf: 10, rank: 1000),
      .lastDay: .init(outOf: 1, rank: 100),
    ]

    var serverEnvironment = ServerEnvironment.failing
    serverEnvironment.database.fetchPlayerByAccessToken = { _ in
      .init(value: .blob)
    }
    serverEnvironment.database.fetchLeaderboardSummary = {
      .init(value: ranks[$0.timeScope]!)
    }
    serverEnvironment.database.submitLeaderboardScore = {
      .init(
        value: .init(
          createdAt: .mock,
          dailyChallengeId: $0.dailyChallengeId,
          gameContext: .solo,
          gameMode: $0.gameMode,
          id: .init(rawValue: UUID()),
          language: $0.language,
          moves: $0.moves,
          playerId: $0.playerId,
          puzzle: $0.puzzle,
          score: $0.score
        )
      )
    }


    serverEnvironment.dictionary.contains = { _, _ in true }
    serverEnvironment.router = .mock

    var environment = GameOverEnvironment.failing
    environment.audioPlayer = .noop
    environment.apiClient = .init(
      middleware: siteMiddleware(environment: serverEnvironment),
      router: .mock
    )
    environment.database.playedGamesCount = { _ in .init(value: 0) }
    environment.mainRunLoop = .immediate
    environment.serverConfig.config = { .init() }
    environment.userNotifications.getNotificationSettings = .none

    let store = TestStore(
      initialState: GameOverState(
        completedGame: .mock,
        isDemo: false
      ),
      reducer: gameOverReducer,
      environment: environment
    )

    store.send(.onAppear)

    store.receive(.delayedOnAppear) {
      $0.isViewEnabled = true
    }
    store.receive(.submitGameResponse(.success(.solo(.init(ranks: ranks))))) {
      $0.summary = .leaderboard(ranks)
    }
  }

  func testBasics() {
    let ranks: [TimeScope: LeaderboardScoreResult.Rank] = [
      .allTime: .init(outOf: 100, rank: 10000),
      .lastWeek: .init(outOf: 10, rank: 1000),
      .lastDay: .init(outOf: 1, rank: 100),
    ]

    var serverEnvironment = ServerEnvironment.failing
    serverEnvironment.dictionary.contains = { _, _ in true }
    serverEnvironment.database.fetchPlayerByAccessToken = { _ in
      .init(value: Player.blob)
    }
    serverEnvironment.database.fetchLeaderboardSummary = {
      .init(value: ranks[$0.timeScope]!)
    }
    serverEnvironment.database.submitLeaderboardScore = { _ in
      .init(
        value: LeaderboardScore(
          createdAt: .mock,
          dailyChallengeId: nil,
          gameContext: .solo,
          gameMode: .timed,
          id: .init(rawValue: UUID()),
          language: .en,
          moves: CompletedGame.mock.moves,
          playerId: Player.blob.id,
          puzzle: .mock,
          score: score("CAB")
        )
      )
    }
    serverEnvironment.router = .mock

    var gameOverEnvironment = GameOverEnvironment.failing
    gameOverEnvironment.audioPlayer = .noop
    gameOverEnvironment.apiClient = .init(
      middleware: siteMiddleware(environment: serverEnvironment),
      router: .mock
    )
    gameOverEnvironment.database.playedGamesCount = { _ in .init(value: 0) }
    gameOverEnvironment.mainRunLoop = self.mainRunLoop.eraseToAnyScheduler()
    gameOverEnvironment.serverConfig.config = { .init() }
    gameOverEnvironment.userNotifications = .noop

    let store = TestStore(
      initialState: GameOverState(
        completedGame: .mock,
        isDemo: false
      ),
      reducer: gameOverReducer,
      environment: gameOverEnvironment
    )

    store.send(.onAppear)

    self.mainRunLoop.advance()
    store.receive(.submitGameResponse(.success(.solo(.init(ranks: ranks))))) {
      $0.summary = .leaderboard(ranks)
    }

    self.mainRunLoop.advance(by: .seconds(2))
    store.receive(.delayedOnAppear) {
      $0.isViewEnabled = true
    }
  }
}
