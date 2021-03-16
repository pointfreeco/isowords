import UIKit

extension UIColor {
  public static func hex(_ hex: UInt) -> Self {
    Self(
      red: CGFloat((hex & 0xff0000) >> 16) / 255,
      green: CGFloat((hex & 0x00ff00) >> 8) / 255,
      blue: CGFloat(hex & 0x0000ff) / 255,
      alpha: 1
    )
  }
}
