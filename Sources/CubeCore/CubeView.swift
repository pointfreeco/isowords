import ComposableArchitecture
import SwiftUI

public struct CubeView: View {
  public let store: Store<CubeSceneView.ViewState, CubeSceneView.ViewAction>

  public init(
    store: Store<CubeSceneView.ViewState, CubeSceneView.ViewAction>
  ) {
    self.store = store
  }

  public var body: some View {
    GeometryReader { geometry in
      CubeRepresentable(size: geometry.size, store: self.store)
    }
  }
}

private struct CubeRepresentable: UIViewRepresentable {
  @AppStorage("enableCubeShadow") var enableCubeShadow = true
  @AppStorage("showSceneStatistics") var showSceneStatistics = false

  let size: CGSize
  let store: Store<CubeSceneView.ViewState, CubeSceneView.ViewAction>

  func makeUIView(context: Context) -> CubeSceneView {
    CubeSceneView(size: self.size, store: self.store)
  }

  func updateUIView(_ sceneView: CubeSceneView, context: Context) {
    sceneView.enableCubeShadow = self.enableCubeShadow
    sceneView.showSceneStatistics = self.showSceneStatistics
  }
}
