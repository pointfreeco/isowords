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

  private let letterNode: SCNNode
  private var viewState: ViewState?

  public init(
    letterGeometry: SCNGeometry,
    viewState: ViewState
  ) {
    self.side = viewState.cubeFace.side
    self.letterNode = SCNNode(geometry: letterGeometry)
    super.init()

    letterNode.castsShadow = false
    letterNode.name = "text"
    letterNode.position = .init(0, 0, 0.01)
    self.addChildNode(letterNode)

    self.category = [.cubeFace, .shadowSurface]
    self.name = "Face: \(viewState.cubeFace.side)"

    switch viewState.cubeFace.side {
    case .top:
      self.eulerAngles = SCNVector3(-CGFloat.pi / 2, 0, 0)
      self.position = SCNVector3(0, 0.5, 0)
    case .left:
      self.position = SCNVector3(0, 0, 0.5)
    case .right:
      self.eulerAngles = SCNVector3(0, CGFloat.pi / 2, 0)
      self.position = SCNVector3(0.5, 0, 0)
    }

    self.update(viewState: viewState)
  }

  func update(viewState: ViewState) {
    guard viewState != self.viewState else { return }
    self.viewState = viewState
    guard viewState.cubeFace.useCount <= 2 else { return }
    self.geometry = plane(
      status: viewState.status,
      useCount: viewState.cubeFace.useCount
    )
    self.letterNode.isHidden = viewState.letterIsHidden
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}
