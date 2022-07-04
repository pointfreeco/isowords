import Combine
import ComposableArchitecture
import Foundation

public struct LowPowerModeClient {
  public var start: Effect<Bool, Never>
  public var startAsync: @Sendable () async -> AsyncStream<Bool>
}
