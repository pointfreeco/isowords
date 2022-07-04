import Combine
import CombineSchedulers
import ComposableArchitecture
import Foundation
import XCTestDynamicOverlay

extension LowPowerModeClient {
  public static let `false` = Self(
    start: Just(false).eraseToEffect(),
    startAsync: { AsyncStream { $0.yield(false) } }
  )
  public static let `true` = Self(
    start: Just(true).eraseToEffect(),
    startAsync: { AsyncStream { $0.yield(true) } }
  )

  #if DEBUG
    public static let failing = Self(
      start: .failing("\(Self.self).start is unimplemented"),
      startAsync: XCTUnimplemented("\(Self.self).startAsync")
    )
    public static var backAndForth: Self {
      Self(
        start: Timer.publish(every: 2, on: .main, in: .default)
          .autoconnect()
          .scan(false) { a, _ in !a }
          .eraseToEffect(),
        startAsync: {
          AsyncStream { continuation in
            let isLowPowerModeEnabled = SendableState(false)
            Task {
              await continuation.yield(isLowPowerModeEnabled.value)
              for await _ in DispatchQueue.main.timer(interval: 2) {
                let isLowPowerModeEnabled = await isLowPowerModeEnabled.modify {
                  $0.toggle()
                  return $0
                }
                continuation.yield(isLowPowerModeEnabled)
              }
            }
          }
        }
      )
    }
  #endif
}
