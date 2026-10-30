import ComposableArchitecture
import SwiftUI

public struct CubeView: View {
  let send: @MainActor (CubeSceneView.ViewAction) -> Void
  let state: @MainActor () -> CubeSceneView.ViewState

  public init(
    state: @escaping @MainActor () -> CubeSceneView.ViewState,
    send: @escaping @MainActor (CubeSceneView.ViewAction) -> Void
  ) {
    self.send = send
    self.state = state
  }

  public init<State, Action>(
    store: Store<State, Action>,
    state: KeyPath<State, CubeSceneView.ViewState>,
    action: @escaping (CubeSceneView.ViewAction) -> Action
  ) {
    self.init(
      state: { store.state[keyPath: state] },
      send: { store.send(action($0)) }
    )
  }

  public var body: some View {
    GeometryReader { geometry in
      CubeRepresentable(size: geometry.size, state: self.state, send: self.send)
    }
  }
}

private struct CubeRepresentable: UIViewRepresentable {
  @AppStorage(.enableCubeShadow) var enableCubeShadow
  @AppStorage(.showSceneStatistics) var showSceneStatistics

  let size: CGSize
  let state: @MainActor () -> CubeSceneView.ViewState
  let send: @MainActor (CubeSceneView.ViewAction) -> Void

  func makeUIView(context: Context) -> CubeSceneView {
    CubeSceneView(size: self.size, state: self.state, send: self.send)
  }

  func updateUIView(_ sceneView: CubeSceneView, context: Context) {
    sceneView.enableCubeShadow = self.enableCubeShadow
    sceneView.showSceneStatistics = self.showSceneStatistics
  }
}
