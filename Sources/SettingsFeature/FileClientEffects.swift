//import ComposableArchitecture
//import FileClient
//
//extension FileClient {
//  public func loadUserSettings() async throws -> UserSettings {
//    try await self.load(UserSettings.self, from: userSettingsFileName)
//  }
//
//  public func save(userSettings: UserSettings) async throws {
//    try await self.save(userSettings, to: userSettingsFileName)
//  }
//}
