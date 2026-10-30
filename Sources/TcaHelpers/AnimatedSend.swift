import ComposableArchitecture
import UIKit

extension FeatureStore {
  @MainActor
  public func send(
    _ action: Action,
    animateWithDuration duration: TimeInterval,
    delay: TimeInterval = 0,
    options animationOptions: UIView.AnimationOptions = []
  ) {
    guard !Task.isCancelled else { return }
    UIView.animate(
      withDuration: duration,
      delay: delay,
      options: animationOptions,
      animations: { _ = try? send(action) }
    )
  }

  @MainActor
  public func modify(
    animateWithDuration duration: TimeInterval,
    delay: TimeInterval = 0,
    options animationOptions: UIView.AnimationOptions = [],
    _ body: @escaping (inout State) -> Void
  ) {
    guard !Task.isCancelled else { return }
    UIView.animate(
      withDuration: duration,
      delay: delay,
      options: animationOptions,
      animations: { _ = try? modify(body) }
    )
  }
}
