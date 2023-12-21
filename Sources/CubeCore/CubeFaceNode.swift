import Combine
import ComposableArchitecture
import SceneKit
import SharedModels
import SwiftUI

public class CubeFaceNode: SCNNode {
  public struct ViewState: Equatable {
    public var cubeFace: CubeFace
    public var letterIsHidden: Bool
    public var status: Status

    public init(
      cubeFace: CubeFace,
      letterIsHidden: Bool = false,
      status: Status
    ) {
      self.cubeFace = cubeFace
      self.letterIsHidden = letterIsHidden
      self.status = status
    }

    public enum Status {
      case deselected
      case selectable
      case selected
    }
  }

  public let side: CubeFace.Side

  private var cancellables: Set<AnyCancellable> = []
  private let uuid = UUID()

  public init(
    letterGeometry: SCNGeometry,
    initialState: ViewState,
    face: StorePublisher<ViewState>
  ) {
    self.side = initialState.cubeFace.side
    super.init()

    let letterNode = SCNNode(geometry: letterGeometry)
    letterNode.castsShadow = false
    letterNode.name = "text"
    letterNode.position = .init(0, 0, 0.01)
    self.addChildNode(letterNode)

    self.category = [.cubeFace, .shadowSurface]
    self.name = "Face: \(initialState.cubeFace.side)"

    switch initialState.cubeFace.side {
    case .top:
      self.eulerAngles = SCNVector3(-CGFloat.pi / 2, 0, 0)
      self.position = SCNVector3(0, 0.5, 0)
    case .left:
      self.position = SCNVector3(0, 0, 0.5)
    case .right:
      self.eulerAngles = SCNVector3(0, CGFloat.pi / 2, 0)
      self.position = SCNVector3(0.5, 0, 0)
    }

    face
      .sink { [weak self] state in
        guard let self = self else { return }
        guard state.cubeFace.useCount <= 2 else { return }
        self.geometry = plane(
          status: state.status,
          useCount: state.cubeFace.useCount
        )
        letterNode.isHidden = state.letterIsHidden
      }
      .store(in: &self.cancellables)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}
