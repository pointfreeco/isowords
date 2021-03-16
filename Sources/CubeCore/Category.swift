import SceneKit

struct Category: OptionSet {
  let rawValue: Int
  static let cubeFace = Self(rawValue: 2)
  static let shadowSurface = Self(rawValue: 4)
}

extension SCNCamera {
  var category: Category {
    get { Category(rawValue: self.categoryBitMask) }
    set { self.categoryBitMask = newValue.rawValue }
  }
}

extension SCNNode {
  var category: Category {
    get { Category(rawValue: self.categoryBitMask) }
    set { self.categoryBitMask = newValue.rawValue }
  }
}

extension SCNLight {
  var category: Category {
    get { Category(rawValue: self.categoryBitMask) }
    set { self.categoryBitMask = newValue.rawValue }
  }
}
