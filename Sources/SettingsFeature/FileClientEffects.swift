import ComposableArchitecture
import FileClient

extension FileClient {
  public func loadUserSettings() -> Effect<Result<UserSettings, NSError>, Never> {
    self.load(UserSettings.self, from: userSettingsFileName)
  }

  public func saveUserSettings(
    userSettings: UserSettings, on queue: AnySchedulerOf<DispatchQueue>
  ) -> Effect<Never, Never> {
    self.save(userSettings, to: userSettingsFileName, on: queue)
  }
}

public let userSettingsFileName = "user-settings"
