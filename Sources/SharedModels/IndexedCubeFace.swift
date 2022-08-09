import CustomDump

public struct IndexedCubeFace: Codable, Hashable, Sendable {
  public var index: LatticePoint
  public var side: CubeFace.Side

  public init(
    index: LatticePoint,
    side: CubeFace.Side
  ) {
    self.index = index
    self.side = side
  }

  public func isTouching(_ other: IndexedCubeFace) -> Bool {
    guard self != other else { return false }

    let otherEdges = other.edges

    return self.edges
      .contains { edge in
        otherEdges.contains { otherEdge in
          edge.isTouching(edge: otherEdge)
        }
      }
  }

  public static let cubeIndices = LatticePoint.cubeIndices.flatMap { index in
    CubeFace.Side.allCases.map { side in
      Self(index: index, side: side)
    }
  }

  private var edges: [Edge] {
    var result: [Edge.Point] = []

    switch self.side {
    case .top:
      result.append(contentsOf: cubeTopFaceVertices.map { $0 + .init(self.index) })
    case .left:
      result.append(contentsOf: cubeLeftFaceVertices.map { $0 + .init(self.index) })
    case .right:
      result.append(contentsOf: cubeRightFaceVertices.map { $0 + .init(self.index) })
    }

    let loop = result + [result[0]]
    return zip(loop, loop.dropFirst())
      .map(Edge.init(start:end:))
  }
}

extension IndexedCubeFace: CustomDumpStringConvertible {
  public var customDumpDescription: String {
    "\(self.index.customDumpDescription)@\(self.side)"
  }
}

private struct Edge: Equatable {
  struct Point: Equatable {
    let x, y, z: Int

    static func + (lhs: Self, rhs: Self) -> Self {
      Self(x: lhs.x + rhs.x, y: lhs.y + rhs.y, z: lhs.z + rhs.z)
    }
  }

  let start: Point
  let end: Point

  func isTouching(edge other: Edge) -> Bool {
    self.start == other.start
      || self.start == other.end
      || self.end == other.start
      || self.end == other.end
  }
}

extension Edge.Point {
  init(_ index: LatticePoint) {
    self.init(x: index.x.rawValue, y: index.y.rawValue, z: index.z.rawValue)
  }
}

private let cubeTopFaceVertices = [
  Edge.Point(x: 0, y: 1, z: 1),
  Edge.Point(x: 0, y: 1, z: 0),
  Edge.Point(x: 1, y: 1, z: 0),
  Edge.Point(x: 1, y: 1, z: 1),
]

private let cubeLeftFaceVertices = [
  Edge.Point(x: 0, y: 1, z: 1),
  Edge.Point(x: 1, y: 1, z: 1),
  Edge.Point(x: 1, y: 0, z: 1),
  Edge.Point(x: 0, y: 0, z: 1),
]

private let cubeRightFaceVertices = [
  Edge.Point(x: 1, y: 1, z: 1),
  Edge.Point(x: 1, y: 1, z: 0),
  Edge.Point(x: 1, y: 0, z: 0),
  Edge.Point(x: 1, y: 0, z: 1),
]
