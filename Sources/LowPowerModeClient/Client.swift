import Combine
import ComposableArchitecture
import Foundation

public struct LowPowerModeClient {
  public var start: Effect<Bool, Never>
}
