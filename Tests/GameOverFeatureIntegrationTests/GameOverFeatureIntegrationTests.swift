import ComposableArchitecture
@_spi(Concurrency) import Dependencies
import ConcurrencyExtras
import Dependencies
import GameOverFeature
import IntegrationTestHelpers
import SharedModels
import SiteMiddleware
import XCTest

class GameOverFeatureIntegrationTests: XCTestCase {
  @MainActor
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
      
      let store = withDependencies {
        $0.audioPlayer = .noop
        $0.apiClient = .init(
          middleware: siteMiddleware(environment: serverEnvironment),
          router: .test
        )
        $0.database.playedGamesCount = { _ in 0 }
        $0.serverConfig.config = { .init() }
        $0.userNotifications.getNotificationSettings = {
          .init(authorizationStatus: .notDetermined)
        }
      } operation: {
        TestStore(
          initialState: GameOver.State(
            completedGame: .mock,
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
        $0.summary = .leaderboard(ranks)
        $0.userNotificationSettings = .init(authorizationStatus: .notDetermined)
      }
      store.expect {
        $0.isViewEnabled = true
      }
    }
  }
}
