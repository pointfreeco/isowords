import Combine
import ComposableArchitecture
import Foundation

extension LowPowerModeClient {
  public static let `false` = Self(start: Just(false).eraseToEffect())
  public static let `true` = Self(start: Just(true).eraseToEffect())

  #if DEBUG
    public static let failing = Self(start: .failing("\(Self.self).start is unimplemented"))
    public static var backAndForth: Self {
      Self(
        start: Timer.publish(every: 2, on: .main, in: .default)
          .autoconnect()
          .scan(false) { a, _ in !a }
          .eraseToEffect()
      )
    }
  #endif
}
