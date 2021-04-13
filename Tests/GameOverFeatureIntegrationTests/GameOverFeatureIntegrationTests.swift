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


extension EitherIO where E == Error {
  public static func _failing(_ title: String) -> Self {
    .init(
      run: .init {
        XCTFail("\(title): EitherIO is unimplemented")
        return .left(AnError())
      })
  }

  struct AnError: Error {}
}

class GameOverFeatureIntegrationTests123: XCTestCase {
  func testSubmitScore() {

    var serverEnvironment = ServerEnvironment.failing
    serverEnvironment.dictionary.contains = { _, _ in true }
    serverEnvironment.database.submitLeaderboardScore = { _ in
      ._failing("submitLeaderboardScore")
    }
    serverEnvironment.database.fetchPlayerByAccessToken = { _ in
      .init(run: .init { .right(.blob) })
    }
    serverEnvironment.router = router(
      date: { .mock },
      decoder: JSONDecoder(),
      encoder: JSONEncoder(),
      secrets: ["deadbeef"],
      sha256: { $0 }
    )

    let middleware = siteMiddleware(environment: serverEnvironment)

    var gameOverEnvironment = GameOverEnvironment.failing
    gameOverEnvironment.audioPlayer = .noop
    gameOverEnvironment.apiClient = .init(
      middleware: middleware,
      router: serverEnvironment.router
    )
    gameOverEnvironment.mainQueue = .immediate
    gameOverEnvironment.mainRunLoop = .immediate

    let store = TestStore(
      initialState: .init(
        completedGame: .init(
          cubes: .mock,
          gameContext: .solo,
          gameMode: .timed,
          gameStartTime: .mock,
          language: .en,
          moves: [
            .init(
              playedAt: .mock,
              playerIndex: nil,
              reactions: nil,
              score: score("CAB"),
              type: .playedWord([
                .init(index: .init(x: .two, y: .two, z: .two), side: .top),
                .init(index: .init(x: .two, y: .two, z: .two), side: .left),
                .init(index: .init(x: .two, y: .two, z: .two), side: .right),
              ])
            )
          ],
          secondsPlayed: 10
        ),
        isDemo: false
      ),
      reducer: gameOverReducer,
      environment: gameOverEnvironment
    )

    // TODO: why is this not returning correct json??
    store.send(.onAppear)
  }
}




















