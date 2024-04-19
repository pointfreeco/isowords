import ComposableArchitecture
import UIKit

public struct UserSettings: Codable, Equatable {
  public var appIcon: AppIcon?
  public var colorScheme: ColorScheme
  public var enableGyroMotion: Bool
  public var enableHaptics: Bool
  public var enableNotifications: Bool
  public var enableReducedAnimation: Bool
  public var musicVolume: Float
  public var sendDailyChallengeReminder: Bool
  public var sendDailyChallengeSummary: Bool
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
    enableNotifications: Bool = false,
    enableReducedAnimation: Bool = false,
    musicVolume: Float = 1,
    sendDailyChallengeReminder: Bool = true,
    sendDailyChallengeSummary: Bool = true,
    soundEffectsVolume: Float = 1
  ) {
    self.appIcon = appIcon
    self.colorScheme = colorScheme
    self.enableGyroMotion = enableGyroMotion
    self.enableHaptics = enableHaptics
    self.enableNotifications = enableNotifications
    self.enableReducedAnimation = enableReducedAnimation
    self.musicVolume = musicVolume
    self.sendDailyChallengeReminder = sendDailyChallengeReminder
    self.sendDailyChallengeSummary = sendDailyChallengeSummary
    self.soundEffectsVolume = soundEffectsVolume
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.appIcon = try? container.decode(AppIcon.self, forKey: .appIcon)
    self.colorScheme = (try? container.decode(ColorScheme.self, forKey: .colorScheme)) ?? .system
    self.enableGyroMotion = (try? container.decode(Bool.self, forKey: .enableGyroMotion)) ?? true
    self.enableHaptics = (try? container.decode(Bool.self, forKey: .enableHaptics)) ?? true
    self.enableNotifications =
      (try? container.decode(Bool.self, forKey: .enableNotifications)) ?? false
    self.enableReducedAnimation =
      (try? container.decode(Bool.self, forKey: .enableReducedAnimation)) ?? false
    self.musicVolume = (try? container.decode(Float.self, forKey: .musicVolume)) ?? 1
    self.soundEffectsVolume = (try? container.decode(Float.self, forKey: .soundEffectsVolume)) ?? 1
    self.sendDailyChallengeReminder =
      (try? container.decode(Bool.self, forKey: .sendDailyChallengeReminder)) ?? true
    self.sendDailyChallengeSummary =
      (try? container.decode(Bool.self, forKey: .sendDailyChallengeSummary)) ?? true
  }
}

extension PersistenceReaderKey where Self == FileStorageKey<UserSettings> {
  public static var userSettings: Self {
    fileStorage(
      FileManager.default
        .urls(for: .documentDirectory, in: .userDomainMask)
        .first!
        .appendingPathComponent("user-settings")
        .appendingPathExtension("json")
    )
  }
}
