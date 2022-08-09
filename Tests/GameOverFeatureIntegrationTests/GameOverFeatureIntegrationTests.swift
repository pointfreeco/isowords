import ComposableArchitecture
import GameOverFeature
import IntegrationTestHelpers
import SharedModels
import SiteMiddleware
import XCTest

@MainActor
class GameOverFeatureIntegrationTests: XCTestCase {
  func testSubmitSoloScore() async {
    let ranks: [TimeScope: LeaderboardScoreResult.Rank] = [
      .allTime: .init(outOf: 10_000, rank: 1_000),
      .lastWeek: .init(outOf: 1_000, rank: 100),
      .lastDay: .init(outOf: 100, rank: 10),
    ]
    var serverEnvironment = ServerEnvironment.unimplemented
    serverEnvironment.database.fetchPlayerByAccessToken = { _ in
      .init(value: .blob)
    }
    serverEnvironment.database.fetchLeaderboardSummary = {
      .init(value: ranks[$0.timeScope]!)
    }
    serverEnvironment.database.submitLeaderboardScore = { _ in
      .init(
        value: .init(
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
    serverEnvironment.dictionary.contains = { _, _ in true }
    serverEnvironment.router = .test

    var environment = GameOverEnvironment.unimplemented
    environment.audioPlayer = .noop
    environment.apiClient = .init(
      middleware: siteMiddleware(environment: serverEnvironment),
      router: .test
    )
    environment.database.playedGamesCount = { _ in 0 }
    environment.mainRunLoop = .immediate
    environment.serverConfig.config = { .init() }
    environment.userNotifications.getNotificationSettings = {
      (try? await Task.never()) ?? .init(authorizationStatus: .notDetermined)
    }

    let store = TestStore(
      initialState: GameOverState(
        completedGame: .mock,
        isDemo: false
      ),
      reducer: gameOverReducer,
      environment: environment
    )

    let task = await store.send(.task)

    await store.receive(.submitGameResponse(.success(.solo(.init(ranks: ranks))))) {
      $0.summary = .leaderboard(ranks)
    }
    await store.receive(.delayedOnAppear) {
      $0.isViewEnabled = true
    }
    await task.cancel()
  }
}
