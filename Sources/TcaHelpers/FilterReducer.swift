import ComposableArchitecture

extension Reducer {
  @inlinable
  public func filter(
    _ predicate: @escaping (State, Action) -> Bool
  ) -> some ReducerOf<Self> {
    FilterReducer(base: self, predicate: predicate)
  }
}

@usableFromInline
struct FilterReducer<Base: Reducer>: Reducer {
  @usableFromInline
  let base: Base

  @usableFromInline
  let predicate: (Base.State, Base.Action) -> Bool

  @usableFromInline
  init(base: Base, predicate: @escaping (Base.State, Base.Action) -> Bool) {
    self.base = base
    self.predicate = predicate
  }

  @inlinable
  public func reduce(
    into state: inout Base.State, action: Base.Action
  ) -> EffectOf<Base> {
    guard self.predicate(state, action) else { return .none }
    return self.base.reduce(into: &state, action: action)
  }
}
