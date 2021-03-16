import ComposableArchitecture
import FeedbackGeneratorClient

extension Reducer {
  func haptics(
    feedbackGenerator: @escaping (Environment) -> FeedbackGeneratorClient,
    gameState: @escaping (State) -> GameState?,
    isEnabled: @escaping (State) -> Bool
  ) -> Self {
    self.onChange(
      of: { gameState($0)?.selectedWord },
      perform: { _, state, _, environment in
        guard isEnabled(state) else { return .none }
        return feedbackGenerator(environment).selectionChanged().fireAndForget()
      })
  }
}
