import Combine
import CombineSchedulers
import ComposableArchitecture
import Foundation
import XCTestDynamicOverlay

extension LowPowerModeClient {
  public static let `false` = Self(
    start: { AsyncStream { $0.yield(false) } }
  )
  
  public static let `true` = Self(
    start: { AsyncStream { $0.yield(true) } }
  )

  #if DEBUG
    public static let unimplemented = Self(
      start: XCTUnimplemented("\(Self.self).start")
    )
    public static var backAndForth: Self {
      Self(
        start: {
          AsyncStream<Bool> { continuation in
            let isLowPowerModeEnabled = ActorIsolated(false)
            Task {
              await continuation.yield(isLowPowerModeEnabled.value)
              for await _ in DispatchQueue.main.timer(interval: 2) {
                let isLowPowerModeEnabled = await isLowPowerModeEnabled
                  .withValue { isLowPowerModeEnabled -> Bool in
                    isLowPowerModeEnabled.toggle()
                    return isLowPowerModeEnabled
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
