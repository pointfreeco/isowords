import ComposableArchitecture

extension ReducerProtocol {
  public func onChange<LocalState: Equatable>(
    of toLocalState: @escaping (State) -> LocalState,
    perform additionalEffects: @escaping (LocalState, inout State, Action) -> Effect<
      Action, Never
    >
  ) -> some ReducerProtocol<State, Action> {
    self.onChange(of: toLocalState) { additionalEffects($1, &$2, $3) }
  }

  public func onChange<LocalState: Equatable>(
    of toLocalState: @escaping (State) -> LocalState,
    perform additionalEffects: @escaping (LocalState, LocalState, inout State, Action) -> Effect<
      Action, Never
    >
  ) -> some ReducerProtocol<State, Action> {
    Reduce { state, action in
      let previousLocalState = toLocalState(state)
      let effects = self.reduce(into: &state, action: action)
      let localState = toLocalState(state)

      return previousLocalState != localState
        ? .merge(effects, additionalEffects(previousLocalState, localState, &state, action))
        : effects
    }
  }
}

extension Reducer {
  public func onChange<LocalState>(
    of toLocalState: @escaping (State) -> LocalState,
    perform additionalEffects: @escaping (LocalState, inout State, Action, Environment) -> Effect<
      Action, Never
    >
  ) -> Self where LocalState: Equatable {
    .init { state, action, environment in
      let previousLocalState = toLocalState(state)
      let effects = self.run(&state, action, environment)
      let localState = toLocalState(state)

      return previousLocalState != localState
        ? .merge(effects, additionalEffects(localState, &state, action, environment))
        : effects
    }
  }

  public func onChange<LocalState>(
    of toLocalState: @escaping (State) -> LocalState,
    perform additionalEffects: @escaping (LocalState, LocalState, inout State, Action, Environment)
      -> Effect<Action, Never>
  ) -> Self where LocalState: Equatable {
    .init { state, action, environment in
      let previousLocalState = toLocalState(state)
      let effects = self.run(&state, action, environment)
      let localState = toLocalState(state)

      return previousLocalState != localState
        ? .merge(
          effects, additionalEffects(previousLocalState, localState, &state, action, environment))
        : effects
    }
  }
}
