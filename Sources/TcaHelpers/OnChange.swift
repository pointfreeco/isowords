import ComposableArchitecture

extension ReducerProtocol {
  @inlinable
  public func onChange<LocalState: Equatable>(
    of toLocalState: @escaping (State) -> LocalState,
    perform additionalEffects: @escaping (LocalState, inout State, Action) -> Effect<
      Action, Never
    >
  ) -> ChangeReducer<Self, LocalState> {
    self.onChange(of: toLocalState) { additionalEffects($1, &$2, $3) }
  }

  @inlinable
  public func onChange<LocalState: Equatable>(
    of toLocalState: @escaping (State) -> LocalState,
    perform additionalEffects: @escaping (LocalState, LocalState, inout State, Action) -> Effect<
      Action, Never
    >
  ) -> ChangeReducer<Self, LocalState> {
    ChangeReducer(upstream: self, toLocalState: toLocalState, perform: additionalEffects)
  }
}

public struct ChangeReducer<Upstream: ReducerProtocol, LocalState: Equatable>: ReducerProtocol {
  @usableFromInline
  let upstream: Upstream

  @usableFromInline
  let toLocalState: (Upstream.State) -> LocalState

  @usableFromInline
  let perform:
    (LocalState, LocalState, inout Upstream.State, Upstream.Action) -> Effect<
      Upstream.Action, Never
    >

  @usableFromInline
  init(
    upstream: Upstream,
    toLocalState: @escaping (Upstream.State) -> LocalState,
    perform: @escaping (LocalState, LocalState, inout Upstream.State, Upstream.Action) -> Effect<
      Upstream.Action, Never
    >
  ) {
    self.upstream = upstream
    self.toLocalState = toLocalState
    self.perform = perform
  }

  @inlinable
  public func reduce(into state: inout Upstream.State, action: Upstream.Action) -> Effect<
    Upstream.Action, Never
  > {
    let previousLocalState = self.toLocalState(state)
    let effects = self.upstream.reduce(into: &state, action: action)
    let localState = self.toLocalState(state)

    return previousLocalState != localState
      ? .merge(effects, self.perform(previousLocalState, localState, &state, action))
      : effects
  }
}
