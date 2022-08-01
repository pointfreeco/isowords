import Combine
import ComposableArchitecture
import Foundation

extension DependencyValues {
  public var lowPowerMode: LowPowerModeClient {
    get { self[LowPowerModeClientKey.self] }
    set { self[LowPowerModeClientKey.self] = newValue }
  }

  private enum LowPowerModeClientKey: LiveDependencyKey {
    static let liveValue = LowPowerModeClient.live
    static let testValue = LowPowerModeClient.unimplemented
  }
}

public struct LowPowerModeClient {
  public var start: @Sendable () async -> AsyncStream<Bool>
}
