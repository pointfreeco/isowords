import Foundation
import SharedModels

public struct InProgressGame: Codable, Equatable {
  public var cubes: ArchivablePuzzle
  public var gameContext: GameContext
  public var gameMode: GameMode
  public var gameStartTime: Date
  var _language: Language?
  public var moves: Moves
  public var secondsPlayed: Int

  private enum CodingKeys: String, CodingKey {
    case cubes
    case gameContext
    case gameMode
    case gameStartTime
    case _language = "language"
    case moves
    case secondsPlayed
  }

  public init(
    cubes: ArchivablePuzzle,
    gameContext: GameContext,
    gameMode: GameMode,
    gameStartTime: Date,
    language: Language = .en,
    moves: Moves,
    secondsPlayed: Int
  ) {
    self.cubes = cubes
    self.gameContext = gameContext
    self.gameMode = gameMode
    self.gameStartTime = gameStartTime
    self._language = language
    self.moves = moves
    self.secondsPlayed = secondsPlayed
  }

  public var language: Language {
    get { self._language ?? .en }
    set { self._language = newValue }
  }

  public var currentScore: Int {
    self.moves.reduce(into: 0) { $0 += $1.score }
  }

  public var dailyChallengeId: DailyChallenge.Id? {
    guard case let .dailyChallenge(id) = self.gameContext else { return nil }
    return id
  }

  public func score(forPlayerIndex index: Move.PlayerIndex) -> Int {
    self.moves.reduce(into: 0) {
      $0 += $1.playerIndex == index ? $1.score : 0
    }
  }
}

#if DEBUG
  extension InProgressGame {
    public static let mock = Self(
      cubes: .mock,
      gameContext: .solo,
      gameMode: .unlimited,
      gameStartTime: .mock,
      moves: [],
      secondsPlayed: 0
    )
  }
#endif
