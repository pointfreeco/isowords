import ComposableArchitecture
import Dependencies
import FeedbackGeneratorClient

extension FeatureProtocol {
  public func haptics<Trigger: Equatable>(
    isEnabled: @escaping (State) -> Bool,
    triggerOnChangeOf trigger: Trigger
  ) -> some Feature {
    self.modifier(Haptics(isEnabled: isEnabled, trigger: trigger))
  }
}

@FeatureModifier
private struct Haptics<State, Action, Trigger: Equatable> {
  let isEnabled: (State) -> Bool
  let trigger: Trigger

  @Dependency(\.feedbackGenerator) var feedbackGenerator

  func body(content: Content) -> some Feature {
    content.onChange(of: trigger) { state in
      guard isEnabled(state) else { return }
      store.addTask { await feedbackGenerator.selectionChanged() }
    }
  }
}
