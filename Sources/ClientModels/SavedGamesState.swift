public struct SavedGamesState: Codable, Equatable {
  public var dailyChallengeUnlimited: InProgressGame?
  public var unlimited: InProgressGame?

  public init(
    dailyChallengeUnlimited: InProgressGame? = nil,
    unlimited: InProgressGame? = nil
  ) {
    self.dailyChallengeUnlimited = dailyChallengeUnlimited
    self.unlimited = unlimited
  }
}

import ComposableArchitecture

extension PersistenceKey where Self == PersistenceKeyDefault<FileStorageKey<SavedGamesState>> {
  public static var savedGames: Self {
    PersistenceKeyDefault(
      .fileStorage(.documentsDirectory.appending(path: "saved-games.json")),
      SavedGamesState()
    )
  }
}
