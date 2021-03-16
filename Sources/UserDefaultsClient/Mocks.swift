extension UserDefaultsClient {
  public static let noop = Self(
    boolForKey: { _ in false },
    dataForKey: { _ in nil },
    doubleForKey: { _ in 0 },
    remove: { _ in .none },
    setBool: { _, _ in .none },
    setData: { _, _ in .none },
    setDouble: { _, _ in .none }
  )
}

#if DEBUG
  import Foundation
  import XCTestDebugSupport

  extension UserDefaultsClient {
    public static let failing = Self(
      boolForKey: {
        key
        in XCTFail("\(Self.self).boolForKey(\(key)) is unimplemented")
        return false
      },
      dataForKey: { key in
        XCTFail("\(Self.self).dataForKey(\(key)) is unimplemented")
        return nil
      },
      doubleForKey: { key in
        XCTFail("\(Self.self).doubleForKey(\(key)) is unimplemented")
        return 0
      },
      remove: { key in .failing("\(Self.self).remove(\(key)) is unimplemented") },
      setBool: { _, key in .failing("\(Self.self).setBool(\(key), _) is unimplemented") },
      setData: { _, key in .failing("\(Self.self).setData(\(key), _) is unimplemented") },
      setDouble: { _, key in .failing("\(Self.self).setDouble(\(key), _) is unimplemented") }
    )

    public mutating func override(_ bool: Bool, forKey key: String) {
      self.boolForKey = { [self] in $0 == key ? bool : self.boolForKey(key) }
    }

    public mutating func override(_ data: Data, forKey key: String) {
      self.dataForKey = { [self] in $0 == key ? data : self.dataForKey(key) }
    }

    public mutating func override(_ double: Double, forKey key: String) {
      self.doubleForKey = { [self] in $0 == key ? double : self.doubleForKey(key) }
    }
  }
#endif
