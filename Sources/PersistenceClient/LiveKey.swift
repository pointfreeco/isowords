import ClientModels
import Dependencies
import Foundation

extension PersistenceClient: DependencyKey {
  private static let userSettingsKey = "co.pointfree.isowords.PersistenceClient.userSettings"
  private static let savedGamesKey = "co.pointfree.isowords.PersistenceClient.savedGames"

  public static var liveValue: PersistenceClient {
    let defaultUserSettings: Data = Data()
    var userSettings = UserDefaults.standard.data(forKey: savedGamesKey) ?? defaultUserSettings
//      .flatMap({ try? decoder.decode(SavedGamesState.self, from: $0) }) ?? defaultUserSettings
    {
      didSet {
        UserDefaults.standard.set(
          try? encoder.encode(userSettings),
          forKey: userSettingsKey
        )
      }
    }

    let defaultSavedGames: SavedGamesState = .init()
    var savedGames = UserDefaults.standard.data(forKey: savedGamesKey)
      .flatMap({ try? decoder.decode(SavedGamesState.self, from: $0) }) ?? defaultSavedGames
    {
      didSet {
        UserDefaults.standard.set(
          try? encoder.encode(savedGames),
          forKey: savedGamesKey
        )
      }
    }

    return Self(
      userSettings: { userSettings },
      setUserSettings: { newUserSettings in
        userSettings = newUserSettings
      },
      savedGames: { savedGames },
      setSavedGames: { newSavedGames in
        savedGames = newSavedGames
      },
      deleteSavedGames: {
        savedGames = .init()
      }
    )
  }
}

private let encoder = { () -> JSONEncoder in
  let encoder = JSONEncoder()
  encoder.dateEncodingStrategy = .secondsSince1970
  return encoder
}()

private let decoder = { () -> JSONDecoder in
  let decoder = JSONDecoder()
  decoder.dateDecodingStrategy = .secondsSince1970
  return decoder
}()
