import Foundation
import Styleguide
import SwiftUI
import UIKit

public struct UserSettingsV2: Codable, Equatable {
  public var appIcon: AppIcon?
  public var colorScheme: ColorScheme
  public var enableGyroMotion: Bool
  public var enableHaptics: Bool
  public var enableReducedAnimation: Bool
  public var musicVolume: Float
  public var soundEffectsVolume: Float

  public enum ColorScheme: String, CaseIterable, Codable {
    case dark
    case light
    case system

    public var userInterfaceStyle: UIUserInterfaceStyle {
      switch self {
      case .dark:
        return .dark
      case .light:
        return .light
      case .system:
        return .unspecified
      }
    }
  }

  public init(
    appIcon: AppIcon? = nil,
    colorScheme: ColorScheme = .system,
    enableGyroMotion: Bool = true,
    enableHaptics: Bool = true,
    enableReducedAnimation: Bool = false,
    musicVolume: Float = 1,
    soundEffectsVolume: Float = 1
  ) {
    self.appIcon = appIcon
    self.colorScheme = colorScheme
    self.enableGyroMotion = enableGyroMotion
    self.enableHaptics = enableHaptics
    self.enableReducedAnimation = enableReducedAnimation
    self.musicVolume = musicVolume
    self.soundEffectsVolume = soundEffectsVolume
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.appIcon = try? container.decode(AppIcon.self, forKey: .appIcon)
    self.colorScheme = (try? container.decode(ColorScheme.self, forKey: .colorScheme)) ?? .system
    self.enableGyroMotion = (try? container.decode(Bool.self, forKey: .enableGyroMotion)) ?? true
    self.enableHaptics = (try? container.decode(Bool.self, forKey: .enableHaptics)) ?? true
    self.enableReducedAnimation =
    (try? container.decode(Bool.self, forKey: .enableReducedAnimation)) ?? false
    self.musicVolume = (try? container.decode(Float.self, forKey: .musicVolume)) ?? 1
    self.soundEffectsVolume = (try? container.decode(Float.self, forKey: .soundEffectsVolume)) ?? 1
  }
}

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

  var color: Color {
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
