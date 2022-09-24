import ClientModels
import ComposableArchitecture
import CubeCore
import CubePreview
import PuzzleGen
import SharedModels
import Styleguide
import SwiftUI

@main
struct CubePreviewPreviewApp: App {
  init() {
    Styleguide.registerFonts()
  }

  var body: some Scene {
    WindowGroup {
      CubePreviewView(
        store: Store(
          initialState: CubePreview.State(
            cubes: .mock,
            isAnimationReduced: false,
            isHapticsEnabled: true,
            isOnLowPowerMode: false,
            moveIndex: 0,
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
            settings: .init()
          ),
          reducer: CubePreview()
            .dependency(\.audioPlayer, .noop)
        )
      )
    }
  }
}
