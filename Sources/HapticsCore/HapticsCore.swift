import ComposableArchitecture
import FeedbackGeneratorClient
import TcaHelpers

extension Reducer {
  public func haptics(
    feedbackGenerator: @escaping (Environment) -> FeedbackGeneratorClient,
    isEnabled: @escaping (State) -> Bool,
    triggerOnChangeOf trigger: @escaping (State) -> AnyHashable
  ) -> Self {
    self.onChange(
      of: trigger,
      perform: { _, state, _, environment in
        .fireAndForget { @MainActor [state] in
          guard isEnabled(state)
          else { return }
          await feedbackGenerator(environment).selectionChanged()
        }
      }
    )
  }
}
