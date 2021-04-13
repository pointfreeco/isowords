//import Combine
//import ComposableArchitecture
//import Overture
//import ServerRouter
//import SharedModels
//import TestHelpers
//import XCTest
//
//@testable import ApiClient
//@testable import AppFeature
//
//class SharedGameTests: XCTestCase {
//  let mainQueue = DispatchQueue.test
//  let mainRunLoop = RunLoop.test
//
//  func testOpenSharedGameUrl() throws {
//    let sharedGameResponse = SharedGameResponse(
//      code: "deadbeef",
//      id: .init(rawValue: .deadbeef),
//      gameMode: .timed,
//      language: .en,
//      moves: [
//        .init(
//          playedAt: .mock,
//          playerIndex: nil,
//          reactions: nil,
//          score: 0,
//          type: .removedCube(.zero)
//        ),
//        .init(
//          playedAt: .mock,
//          playerIndex: nil,
//          reactions: nil,
//          score: 10,
//          type: .playedWord([
//            .init(index: .init(x: .zero, y: .zero, z: .one), side: .left),
//            .init(index: .init(x: .zero, y: .zero, z: .one), side: .right),
//            .init(index: .init(x: .zero, y: .zero, z: .one), side: .top),
//          ])
//        )
//      ],
//      puzzle: update(.mock) {
//        $0.0.0.0 = .init(
//          left: .init(letter: "A", side: .left),
//          right: .init(letter: "B", side: .right),
//          top: .init(letter: "C", side: .top)
//        )
//        $0.0.0.1 = .init(
//          left: .init(letter: "A", side: .left),
//          right: .init(letter: "B", side: .right),
//          top: .init(letter: "C", side: .top)
//        )
//      }
//    )
//
//    let environment = update(AppEnvironment.failing) {
//      $0.apiClient.request = { route in
//        switch route {
//        case .sharedGame(.fetch):
//          return .ok(sharedGameResponse)
//
//        default:
//          fatalError("Unhandled route: \(route)")
//        }
//      }
//      $0.mainQueue = self.mainQueue.eraseToAnyScheduler()
//      $0.mainRunLoop = self.mainRunLoop.eraseToAnyScheduler()
//    }
//
//    let store = TestStore(
//      initialState: .init(),
//      reducer: appReducer,
//      environment: environment
//    )
//
//    store.send(.openUrl(URL(string: "isowords:///sharedGames/deadbeef")!))
//    self.mainQueue.advance()
//    store.receive(.fetchSharedGameResponse(.success(sharedGameResponse))) {
//      $0.route = .playing(
//        .init(
//          cubes: .init(archivableCubes: sharedGameResponse.puzzle),
//          gameContext: .shared("deadbeef"),
//          gameCurrentTime: self.mainRunLoop.now.date,
//          gameMode: .timed,
//          gameStartTime: self.mainRunLoop.now.date,
//          moves: [],
//          secondsPlayed: 0
//        )
//      )
//    }
//  }
//}
