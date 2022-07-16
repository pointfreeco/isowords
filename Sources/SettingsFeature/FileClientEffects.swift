import ComposableArchitecture
import FileClient

extension FileClient {
  @available(*, deprecated)
  public func loadUserSettings() -> Effect<Result<UserSettings, NSError>, Never> {
    self.load(UserSettings.self, from: userSettingsFileName)
  }

  public func loadUserSettingsAsync() async throws -> UserSettings {
    try await self.loadAsync(UserSettings.self, from: userSettingsFileName)
  }

  @available(*, deprecated)
  public func saveUserSettings(
    userSettings: UserSettings, on queue: AnySchedulerOf<DispatchQueue>
  ) -> Effect<Never, Never> {
    self.save(userSettings, to: userSettingsFileName, on: queue)
  }

  public func saveUserSettingsAsync(_ userSettings: UserSettings) async throws -> Void {
    try await self.saveAsync(userSettings, to: userSettingsFileName)
  }
}

public let userSettingsFileName = "user-settings"
