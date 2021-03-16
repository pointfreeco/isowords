import ComposableArchitecture

extension Reducer {
  public func filter(_ predicate: @escaping (State, Action) -> Bool) -> Self {
    Self { state, action, environment in
      predicate(state, action)
        ? self.run(&state, action, environment)
        : .none
    }
  }
}
