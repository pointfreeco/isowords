import Gen
import SwiftUI

extension EnvironmentValues {
  public var date: () -> Date {
    get { self[DateKey.self] }
    set { self[DateKey.self] = newValue }
  }
}

private struct DateKey: EnvironmentKey {
  static var defaultValue: () -> Date {
    Date.init
  }
}
