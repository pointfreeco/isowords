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
  @inlinable
  public func _ifLet<
    ChildState,
    ChildAction,
    Child: ReducerProtocol,
    StatePath: Path<State, ChildState>,
    ActionPath: Path<Action, ChildAction>
  >(
    state toChildState: StatePath,
    action toChildAction: ActionPath,
    @ReducerBuilder<ChildState, ChildAction> then child: () -> Child,
    file: StaticString = #file,
    line: UInt = #line
  ) -> OptionalPathReducer<StatePath, ActionPath, Self, Child>
  where Child.State == ChildState, Child.Action == ChildAction {
    OptionalPathReducer(
      parent: self,
      child: child(),
      toChildState: toChildState,
      toChildAction: toChildAction
    )
  }
}

public struct OptionalPathReducer<
  StatePath: Path,
  ActionPath: Path,
  Parent: ReducerProtocol<StatePath.Root, ActionPath.Root>,
  Child: ReducerProtocol<StatePath.Value, ActionPath.Value>
>: ReducerProtocol {
  @usableFromInline
  let parent: Parent
  let child: Child
  let toChildState: StatePath
  let toChildAction: ActionPath

  @usableFromInline
  init(
    parent: Parent,
    child: Child,
    toChildState: StatePath,
    toChildAction: ActionPath
  ) {
    self.parent = parent
    self.child = child
    self.toChildState = toChildState
    self.toChildAction = toChildAction
  }

  @inlinable
  public func reduce(
    into state: inout Parent.State, action: Parent.Action
  ) -> Effect<Parent.Action, Never> {
    return .merge(
      self.reduceWrapped(into: &state, action: action),
      self.parent.reduce(into: &state, action: action)
    )
  }

  @usableFromInline
  func reduceWrapped(
    into state: inout Parent.State, action: Parent.Action
  ) -> Effect<Parent.Action, Never> {
    guard let childAction = self.toChildAction.extract(from: action)
    else { return Effect<Action, Never>.none }

    guard var childState = self.toChildState.extract(from: state)
    else {
      // TODO: Runtime warning
      return .none
    }

    let effect =
      self.child.reduce(into: &childState, action: childAction)
      .map { childAction -> Action in
        var action = action
        self.toChildAction.set(into: &action, childAction)
        return action
      }
    self.toChildState.set(into: &state, childState)
    return effect
  }
}
