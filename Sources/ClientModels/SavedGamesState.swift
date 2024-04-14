import ComposableArchitecture

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

extension PersistenceReaderKey where Self == FileStorageKey<SavedGamesState> {
  public static var savedGames: Self {
    fileStorage(.documentsDirectory.appending(path: "saved-games.json"))
  }
}
