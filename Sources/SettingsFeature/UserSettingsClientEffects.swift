import ComposableArchitecture
import PersistenceClient

extension UserSettingsClient {
  public func loadUserSettings() async throws -> UserSettings {
    try await self.load(UserSettings.self, from: userSettingsKey)
  }

  public func save(userSettings: UserSettings) async throws {
    try await self.save(userSettings, to: userSettingsKey)
  }
}

public let userSettingsKey = "user-settings"
