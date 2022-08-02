import ComposableArchitecture
import FeedbackGeneratorClient
import TcaHelpers

extension ReducerProtocol {
  public func haptics<Trigger: Equatable>(
    isEnabled: @escaping (State) -> Bool,
    triggerOnChangeOf trigger: @escaping (State) -> Trigger
  ) -> Haptics<Self, Trigger> {
    Haptics(upstream: self, isEnabled: isEnabled, trigger: trigger)
  }
}

public struct Haptics<Upstream: ReducerProtocol, Trigger: Equatable>: ReducerProtocol {
  let upstream: Upstream
  let isEnabled: (Upstream.State) -> Bool
  let trigger: (Upstream.State) -> Trigger

  @Dependency(\.feedbackGenerator) var feedbackGenerator

  public var body: some ReducerProtocol<Upstream.State, Upstream.Action> {
    self.upstream.onChange(of: self.trigger) { _, _, state, _ in
      guard self.isEnabled(state) else { return .none }
      return .fireAndForget { await self.feedbackGenerator.selectionChanged() }
    }
  }
}

extension Reducer {
  public func haptics(
    feedbackGenerator: @escaping (Environment) -> FeedbackGeneratorClient,
    isEnabled: @escaping (State) -> Bool,
    triggerOnChangeOf trigger: @escaping (State) -> AnyHashable
  ) -> Self {
    self.onChange(
      of: trigger,
      perform: { _, state, _, environment in
        guard isEnabled(state) else { return .none }
        return .fireAndForget { await feedbackGenerator(environment).selectionChanged() }
      }
    )
  }
}
