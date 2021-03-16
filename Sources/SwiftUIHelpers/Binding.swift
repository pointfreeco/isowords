import SwiftUI

extension Binding where Value: Equatable {
  // NB: Custom bindings can over-emit in certain situations, like sheet dismissal.
  //     This helper can be used to avoid those over-emissions.
  //     https://gist.github.com/stephencelis/09695c901d3ec9f443069ea8c41c4716
  public func removeDuplicates(by predicate: @escaping (Value, Value) -> Bool) -> Self {
    Binding(
      get: { self.wrappedValue },
      set: { if !predicate(self.wrappedValue, $0) { self.wrappedValue = $0 } }
    )
  }
}

extension Binding where Value: Equatable {
  public func removeDuplicates() -> Self {
    self.removeDuplicates(by: ==)
  }
}
