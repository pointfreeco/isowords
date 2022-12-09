import ClientModels
import Dependencies
import Foundation

extension UserSettingsClient: DependencyKey {
  private static let savedGamesKey = "co.pointfree.isowords.UserSettingsClient.savedGames"

  public static func live(
    savedGames defaultSavedGames: SavedGamesState = .init()
  ) -> Self {
    let documentDirectory = FileManager.default
      .urls(for: .documentDirectory, in: .userDomainMask)
      .first!

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
      delete: {
        try FileManager.default.removeItem(
          at: documentDirectory.appendingPathComponent($0).appendingPathExtension("json")
        )
      },
      load: {
        try Data(
          contentsOf: documentDirectory.appendingPathComponent($0).appendingPathExtension("json")
        )
      },
      save: {
        try $1.write(
          to: documentDirectory.appendingPathComponent($0).appendingPathExtension("json")
        )
      },
      loadSavedGames: { savedGames },
      saveGames: { newSavedGames in
        savedGames = newSavedGames
      }
    )
  }

  public static let liveValue = {
    let documentDirectory = FileManager.default
      .urls(for: .documentDirectory, in: .userDomainMask)
      .first!

    var savedGames = UserDefaults.standard.data(forKey: savedGamesKey)
      .flatMap({ try? decoder.decode(SavedGamesState.self, from: $0) })
    {
      didSet {
        UserDefaults.standard.set(
          savedGames.flatMap { try? encoder.encode($0) },
          forKey: savedGamesKey
        )
      }
    }

    return Self(
      delete: {
        try FileManager.default.removeItem(
          at: documentDirectory.appendingPathComponent($0).appendingPathExtension("json")
        )
      },
      load: {
        try Data(
          contentsOf: documentDirectory.appendingPathComponent($0).appendingPathExtension("json")
        )
      },
      save: {
        try $1.write(
          to: documentDirectory.appendingPathComponent($0).appendingPathExtension("json")
        )
      },
      loadSavedGames: { savedGames },
      saveGames: {

      }
    )
  }()
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
