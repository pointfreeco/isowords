import ComposableArchitecture

extension ReducerProtocol {
  @inlinable
  public func onChange<ChildState: Equatable>(
    of toLocalState: @escaping (State) -> ChildState,
    perform additionalEffects: @escaping (ChildState, inout State, Action) -> Effect<
      Action, Never
    >
  ) -> some ReducerProtocol<State, Action> {
    self.onChange(of: toLocalState) { additionalEffects($1, &$2, $3) }
  }

  @inlinable
  public func onChange<ChildState: Equatable>(
    of toLocalState: @escaping (State) -> ChildState,
    perform additionalEffects: @escaping (ChildState, ChildState, inout State, Action) -> Effect<
      Action, Never
    >
  ) -> some ReducerProtocol<State, Action> {
    ChangeReducer(base: self, toLocalState: toLocalState, perform: additionalEffects)
  }
}

@usableFromInline
struct ChangeReducer<Base: ReducerProtocol, ChildState: Equatable>: ReducerProtocol {
  @usableFromInline
  let base: Base

  @usableFromInline
  let toLocalState: (Base.State) -> ChildState

  @usableFromInline
  let perform:
    (ChildState, ChildState, inout Base.State, Base.Action) -> Effect<
      Base.Action, Never
    >

  @usableFromInline
  init(
    base: Base,
    toLocalState: @escaping (Base.State) -> ChildState,
    perform: @escaping (ChildState, ChildState, inout Base.State, Base.Action) -> Effect<
      Base.Action, Never
    >
  ) {
    self.base = base
    self.toLocalState = toLocalState
    self.perform = perform
  }

  @inlinable
  public func reduce(into state: inout Base.State, action: Base.Action) -> Effect<
    Base.Action, Never
  > {
    let previousLocalState = self.toLocalState(state)
    let effects = self.base.reduce(into: &state, action: action)
    let localState = self.toLocalState(state)

    return previousLocalState != localState
      ? .merge(effects, self.perform(previousLocalState, localState, &state, action))
      : effects
  }
}
