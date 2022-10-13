import ComposableArchitecture
import Foundation
import XCTestDynamicOverlay

extension DependencyValues {
  public var lowPowerMode: LowPowerModeClient {
    get { self[LowPowerModeClient.self] }
    set { self[LowPowerModeClient.self] = newValue }
  }
}

extension LowPowerModeClient: TestDependencyKey {
  public static let previewValue = Self.true

  public static let testValue = Self(
    start: XCTUnimplemented("\(Self.self).start")
  )
}

extension LowPowerModeClient {
  public static let `false` = Self(
    start: { AsyncStream { $0.yield(false) } }
  )

  public static let `true` = Self(
    start: { AsyncStream { $0.yield(true) } }
  )

  public static var backAndForth: Self {
    Self(
      start: {
        AsyncStream<Bool> { continuation in
          let isLowPowerModeEnabled = ActorIsolated(false)
          Task {
            await continuation.yield(isLowPowerModeEnabled.value)
            for await _ in DispatchQueue.main.timer(interval: 2) {
              let isLowPowerModeEnabled =
                await isLowPowerModeEnabled
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
}
