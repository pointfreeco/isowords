extension UserDefaultsClient {
  public static let noop = Self(
    boolForKey: { _ in false },
    dataForKey: { _ in nil },
    doubleForKey: { _ in 0 },
    integerForKey: { _ in 0 },
    remove: { _ in .none },
    removeAsync: { _ in },
    setBool: { _, _ in .none },
    setBoolAsync: { _, _ in },
    setData: { _, _ in .none },
    setDataAsync: { _, _ in },
    setDouble: { _, _ in .none },
    setDoubleAsync: { _, _ in },
    setInteger: { _, _ in .none },
    setIntegerAsync: { _, _ in }
  )
}

#if DEBUG
  import Foundation
  import XCTestDynamicOverlay

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
      integerForKey: { key in
        XCTFail("\(Self.self).integerForKey(\(key)) is unimplemented")
        return 0
      },
      remove: { key in .failing("\(Self.self).remove(\(key)) is unimplemented") },
      removeAsync: XCTUnimplemented("\(Self.self).removeAsync"),
      setBool: { _, key in .failing("\(Self.self).setBool(\(key), _) is unimplemented") },
      setBoolAsync: XCTUnimplemented("\(Self.self).setBoolAsync"),
      setData: { _, key in .failing("\(Self.self).setData(\(key), _) is unimplemented") },
      setDataAsync: XCTUnimplemented("\(Self.self).setDataAsync"),
      setDouble: { _, key in .failing("\(Self.self).setDouble(\(key), _) is unimplemented") },
      setDoubleAsync: XCTUnimplemented("\(Self.self).setDoubleAsync"),
      setInteger: { _, key in .failing("\(Self.self).setInteger(\(key), _) is unimplemented") },
      setIntegerAsync: XCTUnimplemented("\(Self.self).setIntegerAsync")
    )

    public mutating func override(bool: Bool, forKey key: String) {
      self.boolForKey = { [self] in $0 == key ? bool : self.boolForKey(key) }
    }

    public mutating func override(data: Data, forKey key: String) {
      self.dataForKey = { [self] in $0 == key ? data : self.dataForKey(key) }
    }

    public mutating func override(double: Double, forKey key: String) {
      self.doubleForKey = { [self] in $0 == key ? double : self.doubleForKey(key) }
    }

    public mutating func override(integer: Int, forKey key: String) {
      self.integerForKey = { [self] in $0 == key ? integer : self.integerForKey(key) }
    }
  }
#endif
