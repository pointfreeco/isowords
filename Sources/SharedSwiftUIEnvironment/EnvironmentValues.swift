import SwiftUI

extension EnvironmentValues {
  public var opponentImage: UIImage? {
    get { self[OpponentImageKey.self] }
    set { self[OpponentImageKey.self] = newValue }
  }

  public var yourImage: UIImage? {
    get { self[YourImageKey.self] }
    set { self[YourImageKey.self] = newValue }
  }
}

private struct OpponentImageKey: EnvironmentKey {
  static var defaultValue: UIImage? { nil }
}

private struct YourImageKey: EnvironmentKey {
  static var defaultValue: UIImage? { nil }
}
