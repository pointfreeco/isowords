import ComposableArchitecture
import Dependencies

private enum DismissGameKey: DependencyKey {
  static var liveValue: DismissEffect {
    @Dependency(\.dismiss) var dismiss
    return dismiss
  }
}
extension DependencyValues {
  public var dismissGame: DismissEffect {
    get { self[DismissGameKey.self] }
    set { self[DismissGameKey.self] = newValue }
  }
}
