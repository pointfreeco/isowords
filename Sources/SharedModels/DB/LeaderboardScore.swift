import Foundation
import Tagged

public struct LeaderboardScore: Decodable, Equatable {
  public typealias Id = Tagged<Self, UUID>

  public let createdAt: Date
  public let dailyChallengeId: DailyChallenge.Id?
  public let gameContext: GameContext
  public let gameMode: GameMode
  public let id: Id
  public let language: Language
  public let moves: Moves
  public let playerId: Player.Id
  public let puzzle: ArchivablePuzzle
  public let score: Int

  public init(
    createdAt: Date,
    dailyChallengeId: DailyChallenge.Id?,
    gameContext: GameContext,
    gameMode: GameMode,
    id: Id,
    language: Language,
    moves: Moves,
    playerId: Player.Id,
    puzzle: ArchivablePuzzle,
    score: Int
  ) {
    self.createdAt = createdAt
    self.dailyChallengeId = dailyChallengeId
    self.gameContext = gameContext
    self.gameMode = gameMode
    self.id = id
    self.language = language
    self.moves = moves
    self.playerId = playerId
    self.puzzle = puzzle
    self.score = score
  }

  public enum GameContext: String, Codable {
    case dailyChallenge
    case solo
    case turnBased
  }
}
