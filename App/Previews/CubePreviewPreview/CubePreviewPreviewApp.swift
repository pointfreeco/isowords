import ClientModels
import CubeCore
import CubePreview
import PuzzleGen
import SharedModels
import SwiftUI

@main
struct CubePreviewPreviewApp: App {
  var body: some Scene {
    WindowGroup {
      CubePreviewView(
        store: .init(
          initialState: .init(
            cubes: .mock,
            isOnLowPowerMode: false,
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
            ],
            moveIndex: 0,
            settings: .init()
          ),
          reducer: cubePreviewReducer,
          environment: CubePreviewEnvironment(
            feedbackGenerator: .live,
            mainQueue: DispatchQueue.main.eraseToAnyScheduler()
          )
        )
      )
    }
  }
}
