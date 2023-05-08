import ComposableArchitecture
@_spi(Concurrency) import Dependencies
import GameOverFeature
import IntegrationTestHelpers
import SharedModels
import SiteMiddleware
import XCTest

@MainActor
class GameOverFeatureIntegrationTests: XCTestCase {
  func testSubmitSoloScore() async {
    await withMainSerialExecutor {
      let ranks: [TimeScope: LeaderboardScoreResult.Rank] = [
        .allTime: .init(outOf: 10_000, rank: 1_000),
        .lastWeek: .init(outOf: 1_000, rank: 100),
        .lastDay: .init(outOf: 100, rank: 10),
      ]
      var serverEnvironment = ServerEnvironment.testValue
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
      
      let store = TestStore(
        initialState: GameOver.State(
          completedGame: .mock,
          isDemo: false
        ),
        reducer: GameOver()
      )
      
      store.dependencies.audioPlayer = .noop
      store.dependencies.apiClient = .init(
        middleware: siteMiddleware(environment: serverEnvironment),
        router: .test
      )
      store.dependencies.database.playedGamesCount = { _ in 0 }
      store.dependencies.mainRunLoop = .immediate
      store.dependencies.serverConfig.config = { .init() }
      store.dependencies.userNotifications.getNotificationSettings = {
        (try? await Task.never()) ?? .init(authorizationStatus: .notDetermined)
      }
      
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
}
