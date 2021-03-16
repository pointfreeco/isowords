import CoreGraphics
import SharedModels

public struct PanData: Equatable {
  public var normalizedPoint: CGPoint
  public var cubeFaceState: IndexedCubeFace

  public init(
    normalizedPoint: CGPoint,
    cubeFaceState: IndexedCubeFace
  ) {
    self.normalizedPoint = normalizedPoint
    self.cubeFaceState = cubeFaceState
  }
}
