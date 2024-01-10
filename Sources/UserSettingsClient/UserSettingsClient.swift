import Combine
import Dependencies
import UIKit

extension UserSettings: DependencyKey {
  public static let liveValue = Self()
  public static let testValue = Self()
}

public struct UserSettingsClient {
  public var get: @Sendable () -> UserSettings
  public var set: @Sendable (UserSettings) async -> Void
}

extension URL {
  fileprivate static let userSettings = FileManager.default
    .urls(for: .documentDirectory, in: .userDomainMask)
    .first!
    .appendingPathComponent(userSettingsFileName)
    .appendingPathExtension("json")
}

extension UserSettingsClient: DependencyKey {
  public static var liveValue: UserSettingsClient {
    return Self(
      get: {
        do {
          return try JSONDecoder().decode(UserSettings.self, from: Data(contentsOf: .userSettings))
        } catch {
          return UserSettings()
        }
      },
      set: { updatedUserSettings in
        try? JSONEncoder().encode(updatedUserSettings).write(to: .userSettings)
      }
    )
  }

  public static let testValue = Self.mock()

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
