import ComposableArchitecture

extension ReducerProtocol {
  public func filter(_ predicate: @escaping (State, Action) -> Bool) -> FilterReducer<Self> {
    FilterReducer(upstream: self, predicate: predicate)
  }
}

public struct FilterReducer<Upstream: ReducerProtocol>: ReducerProtocol {
  let upstream: Upstream
  let predicate: (Upstream.State, Upstream.Action) -> Bool

  public func reduce(
    into state: inout Upstream.State, action: Upstream.Action
  ) -> Effect<Upstream.Action, Never> {
    guard self.predicate(state, action) else { return .none }
    return self.upstream.reduce(into: &state, action: action)
  }
}
