import Foundation
import Tagged

public struct DailyChallenge: Codable, Equatable {
  public typealias Id = Tagged<Self, UUID>
  public typealias GameNumber = Tagged<(Self, gameNumber: ()), Int>

  public var createdAt: Date
  public var endsAt: Date
  public var gameMode: GameMode
  public var gameNumber: GameNumber
  public var id: Id
  public var language: Language
  public var puzzle: ArchivablePuzzle

  public init(
    createdAt: Date,
    endsAt: Date,
    gameMode: GameMode,
    gameNumber: GameNumber,
    id: DailyChallenge.Id,
    language: Language,
    puzzle: ArchivablePuzzle
  ) {
    self.createdAt = createdAt
    self.endsAt = endsAt
    self.gameMode = gameMode
    self.gameNumber = gameNumber
    self.id = id
    self.language = language
    self.puzzle = puzzle
  }
}

#if DEBUG
  import FirstPartyMocks

  extension DailyChallenge {
    public static let mock = Self(
      createdAt: .mock,
      endsAt: .mock,
      gameMode: .timed,
      gameNumber: 1,
      id: .init(rawValue: .dailyChallengeId),
      language: .en,
      puzzle: .mock
    )
  }
#endif
