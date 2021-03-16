public struct LatticePoint: Codable, Equatable, Hashable {
  public enum Index: Int, CaseIterable, Codable, Comparable {
    case zero = 0
    case one = 1
    case two = 2

    public static func < (lhs: Self, rhs: Self) -> Bool {
      lhs.rawValue < rhs.rawValue
    }
  }

  public var x: Index
  public var y: Index
  public var z: Index

  public init(x: Index, y: Index, z: Index) {
    self.x = x
    self.y = y
    self.z = z
  }

  public static let zero = Self(x: Index.zero, y: .zero, z: .zero)

  public static let cubeIndices = Index.allCases.flatMap { xIndex in
    Index.allCases.flatMap { yIndex in
      Index.allCases.map { zIndex in
        LatticePoint(x: xIndex, y: yIndex, z: zIndex)
      }
    }
  }
}

extension Three {
  public subscript(offset: LatticePoint.Index) -> Element {
    get {
      switch offset {
      case .zero: return self.first
      case .one: return self.second
      case .two: return self.third
      }
    }
    set {
      switch offset {
      case .zero: self.first = newValue
      case .one: self.second = newValue
      case .two: self.third = newValue
      }
    }
  }
}

extension Three {
  public subscript<A>(index: LatticePoint) -> A where Element == Three<Three<A>> {
    get { self[index.x][index.y][index.z] }
    set { self[index.x][index.y][index.z] = newValue }
  }
}

extension LatticePoint {
  public init?(x: Int, y: Int, z: Int) {
    guard
      let x = Index(rawValue: x),
      let y = Index(rawValue: y),
      let z = Index(rawValue: z)
    else { return nil }
    self.init(x: x, y: y, z: z)
  }

  public static func + (lhs: Self, rhs: Self) -> Self? {
    Self(
      x: lhs.x.rawValue + rhs.x.rawValue,
      y: lhs.y.rawValue + rhs.y.rawValue,
      z: lhs.z.rawValue + rhs.z.rawValue
    )
  }
}
