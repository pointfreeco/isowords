import ApplicativeRouter
import ApiClient
import Combine
import ComposableArchitecture
import Either
import GameOverFeature
import HttpPipeline
import IntegrationTestHelpers
import Overture
import ServerRouter
import SharedModels
import SiteMiddleware
import TestHelpers
import XCTest

@testable import LocalDatabaseClient
@testable import UserDefaultsClient

class GameOverFeatureIntegrationTests: XCTestCase {
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
    serverEnvironment.router = .test
    let middleware = siteMiddleware(environment: serverEnvironment)

    var gameOverEnvironment = GameOverEnvironment.failing
    gameOverEnvironment.audioPlayer = .noop
    gameOverEnvironment.apiClient = .init(
      middleware: middleware,
      router: .test
    )
    gameOverEnvironment.database.playedGamesCount = { _ in .init(value: 0) }
    gameOverEnvironment.mainQueue = .immediate
    gameOverEnvironment.mainRunLoop = .immediate
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
    store.receive(.enableView) {
      $0.isViewEnabled = true
    }
    store.receive(.submitGameResponse(.success(.solo(.init(ranks: ranks))))) {
      $0.summary = .leaderboard(ranks)
    }
  }
}

extension CompletedGame {
  static let mock = Self(
    cubes: .mock,
    gameContext: .solo,
    gameMode: .timed,
    gameStartTime: .mock,
    language: .en,
    moves: [.cab],
    secondsPlayed: 10
  )
}

extension Move {
  static let cab = Self(
    playedAt: .mock,
    playerIndex: nil,
    reactions: nil,
    score: SharedModels.score("CAB"),
    type: .playedWord([
      .init(index: .init(x: .two, y: .two, z: .two), side: .top),
      .init(index: .init(x: .two, y: .two, z: .two), side: .left),
      .init(index: .init(x: .two, y: .two, z: .two), side: .right),
    ])
  )
}

extension Router where A == ServerRoute {
  static let test = ServerRouter.router(
    date: { .mock },
    decoder: JSONDecoder(),
    encoder: JSONEncoder(),
    secrets: ["deadbeef"],
    sha256: { $0 }
  )
}
