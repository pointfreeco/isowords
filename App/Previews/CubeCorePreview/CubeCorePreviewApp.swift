import CubeCore
import SharedModels
import SwiftUI

@main
struct CubeCorePreviewApp: App {
  var body: some Scene {
    WindowGroup {
      CubeView(
        store: .init(
          initialState: .init(
            cubes: .mock,
            isOnLowPowerMode: false,
            nub: nil,
            playedWords: [],
            selectedFaceCount: 6,
            selectedWordIsValid: false,
            selectedWordString: "QUICKLY",
            settings: .init(showSceneStatistics: true)
          ),
          reducer: .empty,
          environment: ()
        )
      )
    }
  }
}

extension CubeNode.ViewState {
  static func mock(
    x: LatticePoint.Index,
    y: LatticePoint.Index,
    z: LatticePoint.Index
  ) -> Self {
    Self(
      cubeShakeStartedAt: nil,
      index: .init(x: x, y: y, z: z),
      isCriticallySelected: false,
      isInPlay: true,
      left: .init(cubeFace: .leftMock, status: .deselected),
      right: .init(cubeFace: .rightMock, status: .deselected),
      top: .init(cubeFace: .topMock, status: .deselected)
    )
  }
}

extension CubeSceneView.ViewState.ViewPuzzle {
  public static let mock = Self(
    .init(
      .init(
        .mock(x: .two, y: .zero, z: .zero),
        .mock(x: .zero, y: .two, z: .zero),
        .mock(x: .zero, y: .zero, z: .two)
      ),
      .init(
        .mock(x: .two, y: .two, z: .zero),
        .mock(x: .two, y: .zero, z: .two),
        .mock(x: .zero, y: .two, z: .two)
      ),
      .init(
        .mock(x: .two, y: .two, z: .two),
        .mock(x: .two, y: .two, z: .one),
        .mock(x: .two, y: .one, z: .two)
      )
    ),
    .init(
      .init(
        .mock(x: .one, y: .two, z: .two),
        .mock(x: .zero, y: .zero, z: .zero),
        .mock(x: .one, y: .two, z: .one)
      ),
      .init(
        .mock(x: .one, y: .one, z: .two),
        .mock(x: .zero, y: .two, z: .one),
        .mock(x: .zero, y: .one, z: .two)
      ),
      .init(
        .mock(x: .one, y: .two, z: .zero),
        .mock(x: .two, y: .one, z: .zero),
        .mock(x: .two, y: .zero, z: .one)
      )
    ),
    .init(
      .init(
        .mock(x: .zero, y: .zero, z: .zero),
        .mock(x: .one, y: .zero, z: .two),
        .mock(x: .zero, y: .zero, z: .zero)
      ),
      .init(
        .mock(x: .zero, y: .zero, z: .zero),
        .mock(x: .zero, y: .zero, z: .zero),
        .mock(x: .zero, y: .zero, z: .zero)
      ),
      .init(
        .mock(x: .zero, y: .zero, z: .zero),
        .mock(x: .zero, y: .zero, z: .zero),
        .mock(x: .zero, y: .zero, z: .zero)
      )
    )
  )
}

struct Preview: PreviewProvider {
  static var previews: some View {
    ZStack {
      Circle()
        .fill(
          RadialGradient(
            gradient: Gradient(colors: [.blue, .init(white: 1, opacity: 0)]),
            center: .center,
            startRadius: 1,
            endRadius: 400
          )
        )
        .frame(width: 800, height: 800)

      Circle()
        .fill(
          RadialGradient(
            gradient: Gradient(colors: [.red, .init(white: 1, opacity: 0)]),
            center: .center,
            startRadius: 1,
            endRadius: 400
          )
        )
        .frame(width: 800, height: 800)
        .offset(x: 100, y: 100)

      Circle()
        .fill(
          RadialGradient(
            gradient: Gradient(colors: [.green, .init(white: 1, opacity: 0)]),
            center: .center,
            startRadius: 1,
            endRadius: 400
          )
        )
        .frame(width: 800, height: 800)
        .offset(x: -100, y: -100)
    }
  }
}
