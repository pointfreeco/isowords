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
