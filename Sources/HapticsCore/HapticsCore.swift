import ComposableArchitecture
import FeedbackGeneratorClient
import TcaHelpers

extension Reducer {
  public func haptics<Trigger: Equatable>(
    isEnabled: @escaping (State) -> Bool,
    triggerOnChangeOf trigger: @escaping (State) -> Trigger
  ) -> some ReducerOf<Self> {
    Haptics(base: self, isEnabled: isEnabled, trigger: trigger)
  }
}

@Reducer
private struct Haptics<Base: Reducer, Trigger: Equatable> {
  let base: Base
  let isEnabled: (Base.State) -> Bool
  let trigger: (Base.State) -> Trigger

  @Dependency(\.feedbackGenerator) var feedbackGenerator

  var body: some ReducerOf<Base> {
    self.base.onChange(of: self.trigger) { _, _ in
      Reduce { state, _ in
        guard self.isEnabled(state) else { return .none }
        return .run { _ in await self.feedbackGenerator.selectionChanged() }
      }
    }
  }
}
