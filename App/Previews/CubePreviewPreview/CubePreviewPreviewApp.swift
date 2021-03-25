import ClientModels
import CubeCore
import PuzzleGen
import SharedModels
import SwiftUI

@testable import CubePreview

@main
struct CubePreviewPreviewApp: App {
  var body: some Scene {
    WindowGroup {
      CubePreviewView(
        store: .init(
          initialState: .init(
            game: .init(
              cubes: .mock,
              gameContext: .solo,
              gameCurrentTime: .mock,
              gameMode: .unlimited,
              gameStartTime: .mock,
              moves: [
                .init(
                  playedAt: .mock,
                  playerIndex: nil,
                  reactions: nil,
                  score: 2_000,
                  type: .playedWord([
                    .init(
                      index: .init(x: .two, y: .two, z: .two),
                      side: .top
                    ),
                    .init(
                      index: .init(x: .two, y: .two, z: .one),
                      side: .top
                    ),
                    .init(
                      index: .init(x: .two, y: .two, z: .zero),
                      side: .top
                    ),
                    .init(
                      index: .init(x: .two, y: .two, z: .zero),
                      side: .right
                    ),
                    .init(
                      index: .init(x: .two, y: .two, z: .one),
                      side: .right
                    ),
                    .init(
                      index: .init(x: .two, y: .two, z: .two),
                      side: .right
                    ),
                  ])
                )
              ]
            ),
            nub: .init(),
            moveIndex: 0
          ),
          reducer: cubePreviewReducer,
          environment: CubePreviewEnvironment(
            dictionary: .everyString,
            feedbackGenerator: .live,
            mainQueue: DispatchQueue.main.eraseToAnyScheduler(),
            mainRunLoop: RunLoop.main.eraseToAnyScheduler()
          )
        )
      )
    }
  }
}
