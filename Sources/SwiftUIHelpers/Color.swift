import SwiftUI

extension Color {
  public static func hex(_ hex: UInt) -> Self {
    Self(
      red: Double((hex & 0xff0000) >> 16) / 255,
      green: Double((hex & 0x00ff00) >> 8) / 255,
      blue: Double(hex & 0x0000ff) / 255,
      opacity: 1
    )
  }
}

#if canImport(UIKit)
  import UIKit

  extension Color {
    public init(dynamicProvider: @escaping (UITraitCollection) -> Color) {
      self = Self(UIColor { UIColor(dynamicProvider($0)) })
    }

    public func inverted() -> Self {
      Self(UIColor(self).inverted())
    }
  }

  extension UIColor {
    public func inverted() -> Self {
      Self {
        self.resolvedColor(
          with: .init(userInterfaceStyle: $0.userInterfaceStyle == .dark ? .light : .dark)
        )
      }
    }
  }
#endif
