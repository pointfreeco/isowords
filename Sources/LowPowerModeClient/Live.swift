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
    .eraseToEffect(),
    startAsync: {
      if #available(iOS 15, *) {
        return AsyncStream { continuation in
          continuation.yield(ProcessInfo.processInfo.isLowPowerModeEnabled)
          let task = Task {
            let powerStateDidChange = NotificationCenter.default
              .notifications(named: .NSProcessInfoPowerStateDidChange)
              .map { _ in ProcessInfo.processInfo.isLowPowerModeEnabled }
            for await isLowPowerModeEnabled in powerStateDidChange {
              continuation.yield(isLowPowerModeEnabled)
            }
          }
          continuation.onTermination = { _ in
            task.cancel()
          }
        }
      } else {
        fatalError("TODO: Bump platform requirements")
      }
    }
  )
}
