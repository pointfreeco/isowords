import Combine
import Dependencies
import UIKit

public struct UserSettings: Codable, Equatable {
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

public struct UserSettingsClient {
  public var get: @Sendable () -> UserSettings
  public var set: @Sendable (UserSettings) async -> Void
  public var stream: @Sendable () async -> AsyncStream<UserSettings>

  // setting: (KeyPath<UserSettings, A>) -> A
  //var setting: @Sendable (KeyPath<UserSettings, A>) -> AsyncStream<A>
}

extension UserSettingsClient: DependencyKey {
  public static var liveValue: UserSettingsClient {
    let userSettingsFileURL = FileManager.default
      .urls(for: .documentDirectory, in: .userDomainMask)
      .first!
      .appendingPathComponent(userSettingsFileName)
      .appendingPathExtension("json")
    let initialUserSettingsData = (try? Data(contentsOf: userSettingsFileURL)) ?? Data()
    let initialUserSettings =
      (try? JSONDecoder().decode(UserSettings.self, from: initialUserSettingsData))
      ?? UserSettings()

    let userSettings = LockIsolated(initialUserSettings)
    let subject = PassthroughSubject<UserSettings, Never>()
    return Self(
      get: {
        userSettings.value
      },
      set: { updatedUserSettings in
        userSettings.withValue {
          $0 = updatedUserSettings
          subject.send(updatedUserSettings)
          try? JSONEncoder().encode(updatedUserSettings).write(to: userSettingsFileURL)
        }
      },
      stream: {
        subject.values.eraseToStream()
      }
    )
  }

  public static let testValue = Self(
    get: unimplemented(placeholder: UserSettings()),
    set: unimplemented(),
    stream: unimplemented(placeholder: .never)
  )

  public static func mock(initialUserSettings: UserSettings = UserSettings()) -> Self {
    let userSettings = LockIsolated<UserSettings>(initialUserSettings)
    let subject = PassthroughSubject<UserSettings, Never>()
    return Self(
      get: { userSettings.value },
      set: { updatedUserSettings in
        userSettings.withValue {
          $0 = updatedUserSettings
          subject.send(updatedUserSettings)
        }
      },
      stream: {
        subject.values.eraseToStream()
      }
    )
  }
}

extension DependencyValues {
  public var userSettings: UserSettingsClient {
    get { self[UserSettingsClient.self] }
    set { self[UserSettingsClient.self] = newValue }
  }
}

public let userSettingsFileName = "user-settings"
