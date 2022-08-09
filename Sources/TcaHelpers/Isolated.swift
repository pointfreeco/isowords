import Foundation

@dynamicMemberLookup
@propertyWrapper
public final class Isolated<Value>: @unchecked Sendable {
  private var _value: Value {
    willSet {
      self.lock.lock()
      defer { self.lock.unlock() }
      self.willSet(self._value, newValue)
    }
    didSet {
      self.lock.lock()
      defer { self.lock.unlock() }
      self.didSet(oldValue, self._value)
    }
  }
  private let lock = NSRecursiveLock()
  let willSet: @Sendable (Value, Value) -> Void
  let didSet: @Sendable (Value, Value) -> Void

  // TODO: Make configurable with `willSet`, `didSet`, etc.?
  public init(
    _ value: Value,
    willSet: @escaping @Sendable (Value, Value) -> Void = { _, _ in },
    didSet: @escaping @Sendable (Value, Value) -> Void = { _, _ in }
  ) {
    self._value = value
    self.willSet = willSet
    self.didSet = didSet
  }

  public convenience init(wrappedValue: Value) {
    self.init(wrappedValue)
  }

  public var value: Value {
    _read {
      self.lock.lock()
      defer { self.lock.unlock() }
      yield self._value
    }
    _modify {
      self.lock.lock()
      defer { self.lock.unlock() }
      yield &self._value
    }
  }

  public var wrappedValue: Value {
    _read {
      self.lock.lock()
      defer { self.lock.unlock() }
      yield self._value
    }
    _modify {
      self.lock.lock()
      defer { self.lock.unlock() }
      yield &self._value
    }
  }

  public var projectedValue: Isolated<Value> {
    self
  }

  public subscript<Subject>(dynamicMember keyPath: WritableKeyPath<Value, Subject>) -> Subject {
    _read {
      self.lock.lock()
      defer { self.lock.unlock() }
      yield self._value[keyPath: keyPath]
    }
    _modify {
      self.lock.lock()
      defer { self.lock.unlock() }
      yield &self._value[keyPath: keyPath]
    }
  }

  public func withExclusiveAccess<T: Sendable>(
    _ operation: @Sendable (inout Value) throws -> T
  ) rethrows -> T {
    self.lock.lock()
    defer { self.lock.unlock() }
    return try operation(&self._value)
  }
}
