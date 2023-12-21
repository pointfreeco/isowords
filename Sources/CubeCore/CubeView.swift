import ComposableArchitecture
import SwiftUI

public struct CubeView: View {
  public let viewStore: ViewStore<CubeSceneView.ViewState, CubeSceneView.ViewAction>

  public init(store: Store<CubeSceneView.ViewState, CubeSceneView.ViewAction>) {
    self.viewStore = ViewStore(store, observe: { $0 })
  }

  public var body: some View {
    GeometryReader { geometry in
      CubeRepresentable(size: geometry.size, viewStore: self.viewStore)
    }
  }
}

private struct CubeRepresentable: UIViewRepresentable {
  @AppStorage(.enableCubeShadow) var enableCubeShadow
  @AppStorage(.showSceneStatistics) var showSceneStatistics

  let size: CGSize
  let viewStore: ViewStore<CubeSceneView.ViewState, CubeSceneView.ViewAction>

  func makeUIView(context: Context) -> CubeSceneView {
    CubeSceneView(size: self.size, viewStore: self.viewStore)
  }

  func updateUIView(_ sceneView: CubeSceneView, context: Context) {
    sceneView.enableCubeShadow = self.enableCubeShadow
    sceneView.showSceneStatistics = self.showSceneStatistics
  }
}
