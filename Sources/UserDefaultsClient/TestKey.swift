import Dependencies
import Foundation

extension UserDefaultsClient: TestDependencyKey {
  public static let previewValue = Self.noop
  public static let testValue = Self()
}

extension UserDefaultsClient {
  public static let noop = Self(
    boolForKey: { _ in false },
    dataForKey: { _ in nil },
    doubleForKey: { _ in 0 },
    integerForKey: { _ in 0 },
    remove: { _ in },
    setBool: { _, _ in },
    setData: { _, _ in },
    setDouble: { _, _ in },
    setInteger: { _, _ in }
  )

  public mutating func override(bool: Bool, forKey key: String) {
    self.boolForKey = { [self] in $0 == key ? bool : self.boolForKey($0) }
  }

  public mutating func override(data: Data, forKey key: String) {
    self.dataForKey = { [self] in $0 == key ? data : self.dataForKey($0) }
  }

  public mutating func override(double: Double, forKey key: String) {
    self.doubleForKey = { [self] in $0 == key ? double : self.doubleForKey($0) }
  }

  public mutating func override(integer: Int, forKey key: String) {
    self.integerForKey = { [self] in $0 == key ? integer : self.integerForKey($0) }
  }
}
