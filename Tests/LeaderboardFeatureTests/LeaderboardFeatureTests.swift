import ApiClient
import ComposableArchitecture
import CustomDump
import Dependencies
import Either
import IntegrationTestHelpers
import Overture
import SiteMiddleware
import XCTest

@testable import CubePreview
@testable import LeaderboardFeature
@testable import SharedModels

class LeaderboardFeatureTests: XCTestCase {
  @MainActor
  func testScopeSwitcher() async {
    let store = withDependencies {
      $0.apiClient.apiRequest = { @Sendable _ in try await Task.never() }
    } operation: {
      TestStore(initialState: Leaderboard.State()) {
        Leaderboard()
      } changes: {
        $0.solo.isLoading = true
        $0.solo.resultEnvelope = .placeholder
        $0.vocab.isLoading = true
        $0.vocab.resultEnvelope = .placeholder
      }
    }

    store.send(.scopeTapped(.vocab)) {
      $0.scope = .vocab
    }
    store.send(.scopeTapped(.games)) {
      $0.scope = .games
    }
    await store.dismount()
  }

  @MainActor
  func testTimeScopeSynchronization() async {
    let store = withDependencies {
      $0.apiClient.apiRequest = { @Sendable _ in try await Task.never() }
      $0.audioPlayer = .noop
      $0.feedbackGenerator = .noop
      $0.lowPowerMode = .false
    } operation: {
      TestStore(initialState: Leaderboard.State()) {
        Leaderboard()
      } changes: {
        $0.solo.isLoading = true
        $0.solo.resultEnvelope = .placeholder
        $0.vocab.isLoading = true
        $0.vocab.resultEnvelope = .placeholder
      }
    }

    await store.send(.solo(.timeScopeChanged(.lastDay))) {
      $0.solo.timeScope = .lastDay
      $0.vocab.timeScope = .lastDay
    }
    await store.send(.vocab(.timeScopeChanged(.allTime))) {
      $0.solo.timeScope = .allTime
      $0.vocab.timeScope = .allTime
    }
    await store.dismount()
  }

  @MainActor
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
    let moves: Moves = [
      .init(
        playedAt: .mock,
        playerIndex: nil,
        reactions: nil,
        score: 0,
        type: .removedCube(.init(x: .two, y: .two, z: .two))
      )
    ]
    let fetchWordResponse = FetchVocabWordResponse(
      moveIndex: 0,
      moves: moves,
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
      $0.database.fetchRankedLeaderboardScores = { _ in pure([]) }
      $0.database.fetchVocabLeaderboard = { _, _, _ in
        pure([vocabEntry])
      }
      $0.database.fetchVocabLeaderboardWord = {
        expectNoDifference($0, wordId)
        return pure(fetchWordResponse)
      }
    }
    let middleware = siteMiddleware(environment: siteEnvironment)

    let store = withDependencies {
      $0.apiClient = ApiClient(middleware: middleware, router: .test)
      $0.lowPowerMode = .false
    } operation: {
      TestStore(initialState: Leaderboard.State(scope: .vocab)) {
        Leaderboard()
      } changes: {
        $0.solo.isLoading = true
        $0.solo.resultEnvelope = .placeholder
        $0.vocab.isLoading = true
        $0.vocab.resultEnvelope = .placeholder
      }
    }

    await store.mountTask?.value
    store.expect {
      $0.solo.isLoading = false
      $0.solo.resultEnvelope = ResultEnvelope()
      $0.vocab.isLoading = false
      $0.vocab.resultEnvelope = resultsEnvelope
    }
    await store.send(.vocab(.tappedRow(id: wordId.rawValue)))?.value
    store.expect {
      $0.destination = .cubePreview(
        snap(
          CubePreview.State(
            cubes: .mock,
            isOnLowPowerMode: false,
            moveIndex: 0,
            moves: moves
          )
        )
      )
    }
    store.modify {
      $0.destination = nil
    }
  }
}
