import Combine
import Foundation

extension LowPowerModeClient {
  public static var live = Self(
    start: {
      AsyncStream { continuation in
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
    }
  )
}
