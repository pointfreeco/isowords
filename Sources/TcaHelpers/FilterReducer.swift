import ComposableArchitecture

extension ReducerProtocol {
  @inlinable
  public func filter(_ predicate: @escaping (State, Action) -> Bool) -> FilterReducer<Self> {
    FilterReducer(upstream: self, predicate: predicate)
  }
}

public struct FilterReducer<Upstream: ReducerProtocol>: ReducerProtocol {
  @usableFromInline
  let upstream: Upstream

  @usableFromInline
  let predicate: (Upstream.State, Upstream.Action) -> Bool

  @usableFromInline
  init(upstream: Upstream, predicate: @escaping (Upstream.State, Upstream.Action) -> Bool) {
    self.upstream = upstream
    self.predicate = predicate
  }

  @inlinable
  public func reduce(
    into state: inout Upstream.State, action: Upstream.Action
  ) -> Effect<Upstream.Action, Never> {
    guard self.predicate(state, action) else { return .none }
    return self.upstream.reduce(into: &state, action: action)
  }
}
