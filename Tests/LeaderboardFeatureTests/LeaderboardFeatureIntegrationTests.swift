import ApiClient
import ComposableArchitecture
import Either
import Overture
import SharedModels
import SiteMiddleware
import XCTest

@testable import LeaderboardFeature

class LeaderboardFeatureIntegrationTests: XCTestCase {
  func testSoloIntegrationWithLeaderboardResults() {
    let fetchLeaderboardsEntries = [
      FetchLeaderboardResponse.Entry(
        id: .init(rawValue: .deadbeef),
        isSupporter: false,
        isYourScore: true,
        outOf: 100,
        playerDisplayName: "Blob",
        rank: 1,
        score: 1_000
      )
    ]
    let results = ResultEnvelope(
      outOf: 100,
      results: [
        .init(denseRank: 1, id: .deadbeef, isYourScore: true, rank: 1, score: 1_000, title: "Blob")
      ]
    )

    let siteEnvironment = update(Environment.unimplemented) {
      $0.database.fetchPlayerByAccessToken = { _ in pure(.blob) }
      $0.database.fetchRankedLeaderboardScores = { _ in
        pure(fetchLeaderboardsEntries)
      }
    }
    let middleware = siteMiddleware(environment: siteEnvironment)

    let leaderboardEnvironment = update(LeaderboardEnvironment.failing) {
      $0.apiClient = ApiClient(middleware: middleware)
      $0.mainQueue = DispatchQueue.immediateScheduler.eraseToAnyScheduler()
    }

    let store = TestStore(
      initialState: LeaderboardState(settings: .init()),
      reducer: leaderboardReducer,
      environment: leaderboardEnvironment
    )

    store.send(.solo(.onAppear)) {
      $0.solo.isLoading = true
      $0.solo.resultEnvelope = .placeholder
    }
    store.receive(.solo(.resultsResponse(.success(results)))) {
      $0.solo.isLoading = false
      $0.solo.resultEnvelope = results
    }
  }

  func testVocabIntegrationWithLeaderboardResults() {
    let fetchVocabEntries = [
      FetchVocabLeaderboardResponse.Entry.init(
        denseRank: 1,
        isSupporter: false,
        isYourScore: true,
        outOf: 1_000,
        playerDisplayName: "Blob",
        playerId: .init(rawValue: .deadbeef),
        rank: 1,
        score: 500,
        word: "BANANA",
        wordId: .init(rawValue: .deadbeef)
      )
    ]
    let results = ResultEnvelope(
      outOf: 1_000,
      results: [
        .init(
          denseRank: 1,
          id: .deadbeef,
          isYourScore: true,
          rank: 1,
          score: 500,
          subtitle: "Blob",
          title: "Banana"
        )
      ]
    )

    let siteEnvironment = update(Environment.unimplemented) {
      $0.database.fetchPlayerByAccessToken = { _ in pure(.blob) }
      $0.database.fetchVocabLeaderboard = { _, _, _ in
        pure(fetchVocabEntries)
      }
    }
    let middleware = siteMiddleware(environment: siteEnvironment)

    let leaderboardEnvironment = update(LeaderboardEnvironment.failing) {
      $0.apiClient = ApiClient(middleware: middleware)
      $0.mainQueue = DispatchQueue.immediateScheduler.eraseToAnyScheduler()
    }

    let store = TestStore(
      initialState: LeaderboardState(settings: .init()),
      reducer: leaderboardReducer,
      environment: leaderboardEnvironment
    )

    store.send(.vocab(.onAppear)) {
      $0.vocab.isLoading = true
      $0.vocab.resultEnvelope = .placeholder
    }
    store.receive(.vocab(.resultsResponse(.success(results)))) {
      $0.vocab.isLoading = false
      $0.vocab.resultEnvelope = results
    }
  }
}
