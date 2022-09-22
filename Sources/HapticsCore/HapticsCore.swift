import ComposableArchitecture
import FeedbackGeneratorClient
import TcaHelpers

extension ReducerProtocol {
  public func haptics<Trigger: Equatable>(
    isEnabled: @escaping (State) -> Bool,
    triggerOnChangeOf trigger: @escaping (State) -> Trigger
  ) -> Haptics<Self, Trigger> {
    Haptics(base: self, isEnabled: isEnabled, trigger: trigger)
  }
}

public struct Haptics<Base: ReducerProtocol, Trigger: Equatable>: ReducerProtocol {
  let base: Base
  let isEnabled: (Base.State) -> Bool
  let trigger: (Base.State) -> Trigger

  @Dependency(\.feedbackGenerator) var feedbackGenerator

  public var body: some ReducerProtocol<Base.State, Base.Action> {
    self.base.onChange(of: self.trigger) { _, _, state, _ in
      guard self.isEnabled(state) else { return .none }
      return .fireAndForget { await self.feedbackGenerator.selectionChanged() }
    }
  }
}
