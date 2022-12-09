import ClientModels
import Foundation

public struct PersistenceClient {
  public var userSettings: () -> UserSettings
  public var setUserSettings: (UserSettings) async -> Void

  public var savedGames: () -> SavedGamesState
  public var setSavedGames: (SavedGamesState) async -> Void
  public var deleteSavedGames: () async -> Void
}
