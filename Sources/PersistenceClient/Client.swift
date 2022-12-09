import ClientModels
import Foundation

public struct PersistenceClient {
  public var userSettings: () async -> UserSettings
  public var setUserSettings: (UserSettings) async -> Void

  public var savedGames: () async -> SavedGamesState
  public var setSavedGames: (SavedGamesState) async -> Void
  public var deleteSavedGames: () async -> Void
}
