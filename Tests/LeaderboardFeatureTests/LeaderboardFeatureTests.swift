import ApiClient
import ComposableArchitecture
import Either
import IntegrationTestHelpers
import Overture
import SiteMiddleware
import XCTest

@testable import LeaderboardFeature
@testable import SharedModels

@MainActor
class LeaderboardFeatureTests: XCTestCase {
  func testScopeSwitcher() async {
    let store = TestStore(initialState: Leaderboard.State()) {
      Leaderboard()
    }

    await store.send(.scopeTapped(.vocab)) {
      $0.scope = .vocab
    }
    await store.send(.scopeTapped(.games)) {
      $0.scope = .games
    }
  }

  func testTimeScopeSynchronization() async {
    let store = TestStore(initialState: Leaderboard.State()) {
      Leaderboard()
    } withDependencies: {
      $0.apiClient.apiRequest = { @Sendable _ in try await Task.never() }
      $0.audioPlayer = .noop
      $0.feedbackGenerator = .noop
      $0.lowPowerMode = .false
      $0.mainQueue = .immediate
    }

    let task1 = await store.send(.solo(.timeScopeChanged(.lastDay))) {
      $0.solo.timeScope = .lastDay
      $0.solo.isLoading = true
      $0.vocab.timeScope = .lastDay
    }
    let task2 = await store.send(.vocab(.timeScopeChanged(.allTime))) {
      $0.solo.timeScope = .allTime
      $0.vocab.timeScope = .allTime
      $0.vocab.isLoading = true
    }
    await task1.cancel()
    await task2.cancel()
  }

  func testCubePreview() async {
    let wordId = Word.Id(rawValue: UUID(uuidString: "00000000-0000-0000-0000-00000000304d")!)
    let vocabEntry = FetchVocabLeaderboardResponse.Entry(
      denseRank: 1,
      isSupporter: false,
      isYourScore: false,
      outOf: 1,
      playerDisplayName: "Blob",
      playerId: .init(rawValue: .deadbeef),
      rank: 1,
      score: 100,
      word: "BASKETBALL",
      wordId: wordId
    )
    let fetchWordResponse = FetchVocabWordResponse(
      moveIndex: 0,
      moves: [],
      playerDisplayName: nil,
      playerId: .init(rawValue: .deadbeef),
      puzzle: .mock
    )
    let resultsEnvelope = ResultEnvelope(
      outOf: 1,
      results: [
        .init(
          denseRank: 1,
          id: wordId.rawValue,
          isYourScore: false,
          rank: 1,
          score: 100,
          subtitle: "Blob",
          title: "Basketball"
        )
      ]
    )

    let siteEnvironment = update(ServerEnvironment.testValue) {
      $0.database.fetchPlayerByAccessToken = { _ in pure(.blob) }
      $0.database.fetchVocabLeaderboard = { _, _, _ in
        pure([vocabEntry])
      }
      $0.database.fetchVocabLeaderboardWord = {
        XCTAssertNoDifference($0, wordId)
        return pure(fetchWordResponse)
      }
    }
    let middleware = siteMiddleware(environment: siteEnvironment)

    let store = TestStore(initialState: Leaderboard.State(scope: .vocab)) {
      Leaderboard()
    } withDependencies: {
      $0.apiClient = ApiClient(middleware: middleware, router: .test)
      $0.mainQueue = .immediate
    }


    await store.send(.vocab(.task)) {
      $0.vocab.isLoading = true
      $0.vocab.resultEnvelope = .placeholder
    }
    await store.receive(.vocab(.resultsResponse(.success(resultsEnvelope)))) {
      $0.vocab.isLoading = false
      $0.vocab.resultEnvelope = resultsEnvelope
    }
    await store.send(.vocab(.tappedRow(id: wordId.rawValue)))
    await store.receive(.fetchWordResponse(.success(fetchWordResponse))) {
      $0.destination = .cubePreview(
        .init(
          cubes: .mock,
          isOnLowPowerMode: false,
          moveIndex: 0,
          moves: []
        )
      )
    }
    await store.send(.destination(.dismiss)) {
      $0.destination = nil
    }
  }
}
