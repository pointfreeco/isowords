import ApiClient
import ComposableArchitecture
import Either
import IntegrationTestHelpers
import Overture
import SharedModels
import SiteMiddleware
import XCTest

@testable import LeaderboardFeature

@MainActor
class LeaderboardTests: XCTestCase {
  func testOnAppear() async {
    let store = TestStore(
      initialState: LeaderboardResults.State(timeScope: TimeScope.lastWeek),
      reducer: LeaderboardResults.happyPath
    )

    await store.send(.task) {
      $0.isLoading = true
      $0.resultEnvelope = .placeholder
    }
    await store.receive(.resultsResponse(.success(timedResults))) {
      $0.isLoading = false
      $0.resultEnvelope = timedResults
    }
  }

  func testChangeGameMode() async {
    let store = TestStore(
      initialState: LeaderboardResults.State(timeScope: TimeScope.lastWeek),
      reducer: LeaderboardResults.happyPath
    )

    await store.send(.gameModeButtonTapped(.unlimited)) {
      $0.gameMode = .unlimited
      $0.isLoading = true
    }
    await store.receive(.resultsResponse(.success(untimedResults))) {
      $0.isLoading = false
      $0.resultEnvelope = untimedResults
    }
  }

  func testChangeTimeScope() async {
    let store = TestStore(
      initialState: LeaderboardResults.State(timeScope: TimeScope.lastWeek),
      reducer: LeaderboardResults.happyPath
    )

    await store.send(.tappedTimeScopeLabel) {
      $0.isTimeScopeMenuVisible = true
    }
    await store.send(.timeScopeChanged(.lastDay)) {
      $0.isLoading = true
      $0.isTimeScopeMenuVisible = false
      $0.timeScope = .lastDay
    }
    await store.receive(.resultsResponse(.success(timedResults))) {
      $0.isLoading = false
      $0.resultEnvelope = timedResults
    }
  }

  func tetsUnhappyPath() async {
    struct SomeError: Error {}

    let store = TestStore(
      initialState: LeaderboardResults.State(timeScope: TimeScope.lastWeek),
      reducer: LeaderboardResults(loadResults: { _, _ in throw SomeError() })
    )

    await store.send(.task) {
      $0.isLoading = true
    }
    await store.receive(.resultsResponse(.failure(ApiError(error: SomeError())))) {
      $0.isLoading = false
      $0.resultEnvelope = nil
    }
  }
}

private let uuid = UUID.incrementing

private let timedResults = ResultEnvelope(
  outOf: 10,
  results: (1...10).map { idx in
    ResultEnvelope.Result(
      denseRank: idx,
      id: uuid(),
      rank: idx,
      score: 1_000,
      subtitle: "Timed",
      title: "Blob \(idx)"
    )
  }
)

private let untimedResults = ResultEnvelope(
  outOf: 10,
  results: (1...10).map { idx in
    ResultEnvelope.Result(
      denseRank: idx,
      id: uuid(),
      rank: idx,
      score: 1_000,
      subtitle: "Untimed",
      title: "Blob \(idx)"
    )
  }
)

extension LeaderboardResults {
  fileprivate static var happyPath: Self {
    Self(
      loadResults: { gameMode, _ in
        switch gameMode {
        case .timed:
          return timedResults
        case .unlimited:
          return untimedResults
        }
      }
    )
  }
}
