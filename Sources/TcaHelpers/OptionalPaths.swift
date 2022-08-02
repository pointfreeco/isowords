import ComposableArchitecture

public protocol Path<Root, Value> {
  associatedtype Root
  associatedtype Value
  func extract(from root: Root) -> Value?
  func set(into root: inout Root, _ value: Value)
}

extension WritableKeyPath: Path {
  public func extract(from root: Root) -> Value? {
    root[keyPath: self]
  }

  public func set(into root: inout Root, _ value: Value) {
    root[keyPath: self] = value
  }
}

extension CasePath: Path {
  public func set(into root: inout Root, _ value: Value) {
    root = self.embed(value)
  }
}

public struct OptionalPath<Root, Value>: Path {
  private let _extract: (Root) -> Value?
  private let _set: (inout Root, Value) -> Void

  public init(
    extract: @escaping (Root) -> Value?,
    set: @escaping (inout Root, Value) -> Void
  ) {
    self._extract = extract
    self._set = set
  }

  public func extract(from root: Root) -> Value? {
    self._extract(root)
  }

  public func set(into root: inout Root, _ value: Value) {
    self._set(&root, value)
  }

  public init(
    _ keyPath: WritableKeyPath<Root, Value?>
  ) {
    self.init(
      extract: { $0[keyPath: keyPath] },
      set: { $0[keyPath: keyPath] = $1 }
    )
  }

  public init(
    _ casePath: CasePath<Root, Value>
  ) {
    self.init(
      extract: casePath.extract(from:),
      set: { $0 = casePath.embed($1) }
    )
  }

  public func appending<AppendedValue>(
    path: OptionalPath<Value, AppendedValue>
  ) -> OptionalPath<Root, AppendedValue> {

    .init(
      extract: { self.extract(from: $0).flatMap(path.extract(from:)) },
      set: { root, appendedValue in
        guard var value = self.extract(from: root) else { return }
        path.set(into: &value, appendedValue)
        self.set(into: &root, value)
      }
    )
  }

  public func appending<AppendedValue>(
    path: CasePath<Value, AppendedValue>
  ) -> OptionalPath<Root, AppendedValue> {

    self.appending(path: .init(path))
  }

  public func appending<AppendedValue>(
    path: WritableKeyPath<Value, AppendedValue>
  ) -> OptionalPath<Root, AppendedValue> {

    .init(
      extract: { self.extract(from: $0).map { $0[keyPath: path] } },
      set: { root, appendedValue in
        guard var value = self.extract(from: root) else { return }
        value[keyPath: path] = appendedValue
        self.set(into: &root, value)
      }
    )
  }

  // TODO: Is it safe to keep this overload?
  public func appending<AppendedValue>(
    path: WritableKeyPath<Value, AppendedValue?>
  ) -> OptionalPath<Root, AppendedValue> {

    self.appending(path: .init(path))
  }
}

extension CasePath {
  public func appending<AppendedValue>(
    path: OptionalPath<Value, AppendedValue>
  ) -> OptionalPath<Root, AppendedValue> {

    OptionalPath(self).appending(path: path)
  }

  public func appending<AppendedValue>(
    path: WritableKeyPath<Value, AppendedValue>
  ) -> OptionalPath<Root, AppendedValue> {

    OptionalPath(self).appending(path: path)
  }

  // TODO: Is it safe to keep this overload?
  public func appending<AppendedValue>(
    path: WritableKeyPath<Value, AppendedValue?>
  ) -> OptionalPath<Root, AppendedValue> {

    OptionalPath(self).appending(path: path)
  }
}

extension WritableKeyPath {
  public func appending<AppendedValue>(
    path: OptionalPath<Value, AppendedValue>
  ) -> OptionalPath<Root, AppendedValue> {

    OptionalPath(
      extract: { path.extract(from: $0[keyPath: self]) },
      set: { root, appendedValue in path.set(into: &root[keyPath: self], appendedValue) }
    )
  }

  public func appending<AppendedValue>(
    path: CasePath<Value, AppendedValue>
  ) -> OptionalPath<Root, AppendedValue> {

    self.appending(path: .init(path))
  }
}

extension OptionalPath where Root == Value {
  public static var `self`: OptionalPath {
    .init(.self)
  }
}

extension OptionalPath where Root == Value? {
  public static var some: OptionalPath {
    .init(/Optional.some)
  }
}

extension ReducerProtocol {
  public func _ifLet<
    Wrapped: ReducerProtocol,
    StatePath: Path<State, Wrapped.State>,
    ActionPath: Path<Action, Wrapped.Action>
  >(
    state toWrappedState: StatePath,
    action toWrappedAction: ActionPath,
    @ReducerBuilderOf<Wrapped> then wrapped: () -> Wrapped,
    file: StaticString = #file,
    line: UInt = #line
  ) -> some ReducerProtocol<State, Action> {
    OptionalPathReducer(
      upstream: self,
      wrapped: wrapped(),
      toWrappedState: toWrappedState,
      toWrappedAction: toWrappedAction
    )
  }
}

struct OptionalPathReducer<
  StatePath: Path,
  ActionPath: Path,
  Upstream: ReducerProtocol<StatePath.Root, ActionPath.Root>,
  Wrapped: ReducerProtocol<StatePath.Value, ActionPath.Value>
>: ReducerProtocol {
  let upstream: Upstream
  let wrapped: Wrapped
  let toWrappedState: StatePath
  let toWrappedAction: ActionPath

  public func reduce(
    into state: inout Upstream.State, action: Upstream.Action
  ) -> Effect<Upstream.Action, Never> {
    return .merge(
      self.reduceWrapped(into: &state, action: action),
      self.upstream.reduce(into: &state, action: action)
    )
  }

  func reduceWrapped(
    into state: inout Upstream.State, action: Upstream.Action
  ) -> Effect<Upstream.Action, Never> {
    guard let wrappedAction = self.toWrappedAction.extract(from: action)
    else { return Effect<Action, Never>.none }

    guard var wrappedState = self.toWrappedState.extract(from: state)
    else {
      // TODO: Runtime warning
      return .none
    }

    let effect =
    self.wrapped.reduce(into: &wrappedState, action: wrappedAction)
      .map { wrappedAction -> Action in
        var action = action
        self.toWrappedAction.set(into: &action, wrappedAction)
        return action
      }
    self.toWrappedState.set(into: &state, wrappedState)
    return effect
  }
}

extension Reducer {
  public func _pullback<GlobalState, GlobalAction, GlobalEnvironment, StatePath, ActionPath>(
    state toLocalState: StatePath,
    action toLocalAction: ActionPath,
    environment toLocalEnvironment: @escaping (GlobalEnvironment) -> Environment,
    breakpointOnNil: Bool = true,
    file: StaticString = #file,
    line: UInt = #line
  ) -> Reducer<GlobalState, GlobalAction, GlobalEnvironment>
  where
    StatePath: Path, StatePath.Root == GlobalState, StatePath.Value == State,
    ActionPath: Path, ActionPath.Root == GlobalAction, ActionPath.Value == Action
  {

    return .init { globalState, globalAction, globalEnvironment in

      guard let localAction = toLocalAction.extract(from: globalAction)
      else { return .none }

      guard var localState = toLocalState.extract(from: globalState)
      else {
        #if DEBUG
          runtimeWarning(
            """
            Warning: Reducer._pullback@%@:%d

            "%@" was received by an optional reducer when its state was "nil". This can happen for \
            a few reasons:

            * The optional reducer was combined with or run from another reducer that set "%@" to \
            "nil" before the optional reducer ran. Combine or run optional reducers before \
            reducers that can set their state to "nil". This ensures that optional reducers can \
            handle their actions while their state is still non-"nil".

            * An active effect emitted this action while state was "nil". Make sure that effects
            for this optional reducer are canceled when optional state is set to "nil".

            * This action was sent to the store while state was "nil". Make sure that actions \
            for this reducer can only be sent to a view store when state is non-"nil". In \
            SwiftUI applications, use "IfLetStore".
            """,
            [
              "\(file)",
              line,
              "\(globalAction)",
              "\(State.self)"
            ]
          )
        #endif
        return .none
      }

      let effect =
        self.run(&localState, localAction, toLocalEnvironment(globalEnvironment))
        .map { localAction -> GlobalAction in
          var globalAction = globalAction
          toLocalAction.set(into: &globalAction, localAction)
          return globalAction
        }
      toLocalState.set(into: &globalState, localState)
      return effect
    }
  }
}
