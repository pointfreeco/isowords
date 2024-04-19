import SwiftUI

extension _AppStorageKey where Value == Bool {
  public static let enableCubeShadow = _AppStorageKey(key: "enableCubeShadow", defaultValue: true)
  public static let showSceneStatistics = _AppStorageKey(key: "showSceneStatistics", defaultValue: false)
}

public struct _AppStorageKey<Value> {
  public let key: String
  public let defaultValue: Value
}

extension AppStorage {
  public init(_ key: _AppStorageKey<Value>, store: UserDefaults? = nil) where Value == Bool {
    self.init(wrappedValue: key.defaultValue, key.key, store: store)
  }
  public init(_ key: _AppStorageKey<Value>, store: UserDefaults? = nil) where Value == Int {
    self.init(wrappedValue: key.defaultValue, key.key, store: store)
  }
  public init(_ key: _AppStorageKey<Value>, store: UserDefaults? = nil) where Value == Double {
    self.init(wrappedValue: key.defaultValue, key.key, store: store)
  }
  public init(_ key: _AppStorageKey<Value>, store: UserDefaults? = nil) where Value == String {
    self.init(wrappedValue: key.defaultValue, key.key, store: store)
  }
  public init(_ key: _AppStorageKey<Value>, store: UserDefaults? = nil) where Value == Data {
    self.init(wrappedValue: key.defaultValue, key.key, store: store)
  }
  public init(_ key: _AppStorageKey<Value>, store: UserDefaults? = nil)
  where Value: RawRepresentable, Value.RawValue == Int {
    self.init(wrappedValue: key.defaultValue, key.key, store: store)
  }
  public init(_ key: _AppStorageKey<Value>, store: UserDefaults? = nil)
  where Value: RawRepresentable, Value.RawValue == String {
    self.init(wrappedValue: key.defaultValue, key.key, store: store)
  }
}

extension AppStorage where Value: ExpressibleByNilLiteral {
  public init(_ key: _AppStorageKey<Value>, store: UserDefaults? = nil) where Value == Bool? {
    self.init(key.key, store: store)
  }
  public init(_ key: _AppStorageKey<Value>, store: UserDefaults? = nil) where Value == Int? {
    self.init(key.key, store: store)
  }
  public init(_ key: _AppStorageKey<Value>, store: UserDefaults? = nil) where Value == Double? {
    self.init(key.key, store: store)
  }
  public init(_ key: _AppStorageKey<Value>, store: UserDefaults? = nil) where Value == String? {
    self.init(key.key, store: store)
  }
  public init(_ key: _AppStorageKey<Value>, store: UserDefaults? = nil) where Value == Data? {
    self.init(key.key, store: store)
  }
}
