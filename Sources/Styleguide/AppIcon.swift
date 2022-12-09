import SwiftUI

public enum AppIcon: String, Codable, CaseIterable, Hashable {
  case icon1 = "icon-1"
  case icon2 = "icon-2"
  case icon3 = "icon-3"
  case icon4 = "icon-4"
  case icon5 = "icon-5"
  case icon6 = "icon-6"
  case icon7 = "icon-7"
  case icon8 = "icon-8"
  case iso = "icon-iso"

  public var color: Color {
    switch self {
    case .icon1:
      return .isowordsYellow
    case .icon2:
      return .isowordsOrange
    case .icon3:
      return .isowordsRed

    case .icon4, .icon5, .icon6, .icon7, .icon8, .iso:
      return Color(
        UIColor { trait in
          trait.userInterfaceStyle == .light
          ? .black
          : .white
        }
      )
    }
  }
}
