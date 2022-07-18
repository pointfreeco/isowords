import ComposableArchitecture
import UIKit

extension Send {
  public func callAsFunction(
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
      animations: { self.send(action) }
    )
  }
}
