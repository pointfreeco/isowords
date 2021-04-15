import Combine
import ComposableArchitecture

extension Effect {
  public func deferred<S: Scheduler>(
    for dueTime: S.SchedulerTimeType.Stride,
    scheduler: S,
    options: S.SchedulerOptions? = nil
  ) -> Effect {
    Just(())
      .setFailureType(to: Failure.self)
      .delay(for: dueTime, scheduler: scheduler, options: options)
      .flatMap { self }
      .eraseToEffect()
  }
}
