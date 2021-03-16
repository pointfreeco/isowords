import SceneKit
import SwiftUI

func plane(
  status: CubeFaceNode.ViewState.Status,
  useCount: Int
) -> SCNGeometry {
  let color = planeColor(status: status, useCount: useCount)

  if let plane = planeGeometries[color] {
    return plane
  }

  let plane = SCNPlane(width: 1, height: 1)
  plane.firstMaterial?.diffuse.contents = color
  plane.firstMaterial?.multiply.contents = UIImage(named: "border", in: Bundle.module, with: nil)
  planeGeometries[color] = plane

  return plane
}

func planeColor(
  status: CubeFaceNode.ViewState.Status,
  useCount: Int
) -> UIColor {
  switch (status, useCount) {
  case (.deselected, 0):
    return .cubeFaceDefaultColor

  case (.deselected, 1):
    return .cubeFaceUsedColor

  case (.deselected, 2):
    return .cubeFaceCriticalColor

  case (.selectable, 0...2):
    return .cubeFaceSelectableColor

  case (.selected, 0...2):
    return .cubeFaceSelectedColor

  default:
    return .cubeRemovedColor
  }
}

private var textGeometries: [String: SCNGeometry] = [:]
private var planeGeometries: [UIColor: SCNGeometry] = [:]
