import ApiClient
import ComposableArchitecture
import Either
import IntegrationTestHelpers
import Overture
import SiteMiddleware
import XCTest

@testable import LeaderboardFeature
@testable import SharedModels

class LeaderboardFeatureTests: XCTestCase {

  func testScopeSwitcher() {
    let store = TestStore(
      initialState: .init(isHapticsEnabled: false, settings: .init()),
      reducer: leaderboardReducer,
      environment: .failing
    )

    store.send(.scopeTapped(.vocab)) {
      $0.scope = .vocab
    }
    store.send(.scopeTapped(.games)) {
      $0.scope = .games
    }
  }

  func testTimeScopeSynchronization() {
    let store = TestStore(
      initialState: .init(isHapticsEnabled: false, settings: .init()),
      reducer: leaderboardReducer,
      environment: .init(
        apiClient: .noop,
        audioPlayer: .noop,
        feedbackGenerator: .noop,
        lowPowerMode: .false,
        mainQueue: .immediate
      )
    )

    store.send(.solo(.timeScopeChanged(.lastDay))) {
      $0.solo.timeScope = .lastDay
      $0.solo.isLoading = true
      $0.vocab.timeScope = .lastDay
    }
    store.send(.vocab(.timeScopeChanged(.allTime))) {
      $0.solo.timeScope = .allTime
      $0.vocab.timeScope = .allTime
      $0.vocab.isLoading = true
    }
  }

  func testCubePreview() {
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

    let siteEnvironment = update(ServerEnvironment.failing) {
      $0.database.fetchPlayerByAccessToken = { _ in pure(.blob) }
      $0.database.fetchVocabLeaderboard = { _, _, _ in
        pure([vocabEntry])
      }
      $0.database.fetchVocabLeaderboardWord = {
        XCTAssertEqual($0, wordId)
        return pure(fetchWordResponse)
      }
    }
    let middleware = siteMiddleware(environment: siteEnvironment)

    let leaderboardEnvironment = update(LeaderboardEnvironment.failing) {
      $0.apiClient = ApiClient(middleware: middleware, router: .test)
      $0.mainQueue = .immediate
    }

    let store = TestStore(
      initialState: LeaderboardState(
        isHapticsEnabled: false,
        scope: .vocab,
        settings: .init()
      ),
      reducer: leaderboardReducer,
      environment: leaderboardEnvironment
    )

    store.send(.vocab(.onAppear)) {
      $0.vocab.isLoading = true
      $0.vocab.resultEnvelope = .placeholder
    }
    store.receive(.vocab(.resultsResponse(.success(resultsEnvelope)))) {
      $0.vocab.isLoading = false
      $0.vocab.resultEnvelope = resultsEnvelope
    }
    store.send(.vocab(.tappedRow(id: wordId.rawValue)))
    store.receive(.fetchWordResponse(.success(fetchWordResponse))) {
      $0.cubePreview = .init(
        cubes: .mock,
        isAnimationReduced: false,
        isHapticsEnabled: false,
        isOnLowPowerMode: false,
        moveIndex: 0,
        moves: [],
        settings: .init()
      )
    }
    store.send(.dismissCubePreview) {
      $0.cubePreview = nil
    }
  }
}
