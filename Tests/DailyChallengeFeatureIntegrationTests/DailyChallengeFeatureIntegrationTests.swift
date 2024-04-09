import ApiClient
import ComposableArchitecture
import DailyChallengeFeature
@_spi(Concurrency) import Dependencies
import Either
import IntegrationTestHelpers
import Overture
import ServerRouter
import SharedModels
import SiteMiddleware
import TestHelpers
import XCTest

@testable import LeaderboardFeature

class DailyChallengeFeatureTests: XCTestCase {
  @MainActor
  func testBasics() async {
    await withMainSerialExecutor {
      let uuid = UUID.incrementing
      let currentPlayer = Player.blob

      let timedResult = FetchDailyChallengeResultsResponse.Result(
        isSupporter: false,
        isYourScore: true,
        outOf: 10,
        playerDisplayName: "Blob",
        playerId: currentPlayer.id,
        rank: 1,
        score: 1_000
      )
      let timedResultEnvelope = ResultEnvelope(
        outOf: 10,
        results: [
          .init(
            denseRank: 1,
            id: currentPlayer.id.rawValue,
            isYourScore: true,
            rank: 1,
            score: 1_000,
            subtitle: nil,
            title: "Blob"
          )
        ]
      )
      let unlimitedResult = FetchDailyChallengeResultsResponse.Result(
        isSupporter: false,
        isYourScore: false,
        outOf: 10,
        playerDisplayName: "Blob Jr",
        playerId: .init(rawValue: uuid()),
        rank: 1,
        score: 1_000
      )
      let historyResult = DailyChallengeHistoryResponse.Result(
        createdAt: .mock,
        gameNumber: 42,
        isToday: true,
        rank: 1
      )

      let serverEnvironment = update(ServerEnvironment.testValue) {
        $0.database.fetchPlayerByAccessToken = { _ in pure(currentPlayer) }
        $0.database.fetchDailyChallengeResults = { request in
          switch request.gameMode {
          case .timed:
            return pure([timedResult])
          case .unlimited:
            return pure([unlimitedResult])
          }
        }
        $0.database.fetchDailyChallengeHistory = { request in
          pure([historyResult])
        }
      }

      let store = TestStore(initialState: DailyChallengeResults.State()) {
        DailyChallengeResults()
      } withDependencies: {
        $0.apiClient = ApiClient(
          middleware: siteMiddleware(environment: serverEnvironment),
          router: .test
        )
      }

      await store.send(.leaderboardResults(.task)) {
        $0.leaderboardResults.isLoading = true
        $0.leaderboardResults.resultEnvelope = .placeholder
      }
      await store.receive(\.leaderboardResults.resultsResponse.success) {
        $0.leaderboardResults.isLoading = false
        $0.leaderboardResults.resultEnvelope = timedResultEnvelope
      }
      await store.send(.loadHistory)
      await store.receive(\.fetchHistoryResponse.success) {
        $0.history = .init(results: [historyResult])
      }
    }
  }
}
