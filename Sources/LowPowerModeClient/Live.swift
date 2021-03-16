import Combine
import Foundation

extension LowPowerModeClient {
  public static var live = Self(
    start: Publishers.Merge(
      Deferred { Just(ProcessInfo.processInfo.isLowPowerModeEnabled) },

      NotificationCenter.default
        .publisher(for: .NSProcessInfoPowerStateDidChange)
        .map { _ in ProcessInfo.processInfo.isLowPowerModeEnabled }
    )
    .eraseToEffect()
  )
}
