import Combine
import Dependencies
import UIKit

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
