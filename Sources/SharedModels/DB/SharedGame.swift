import Foundation
import Tagged

public struct SharedGame: Codable, Equatable {
  public typealias Code = Tagged<Self, String>
  public typealias Id = Tagged<Self, UUID>

  public let code: Code
  public let createdAt: Date
  public let gameMode: GameMode
  public let id: Id
  public let language: Language
  public let moves: Moves
  public let playerId: Player.Id
  public let puzzle: ArchivablePuzzle

  public init(
    code: Code,
    createdAt: Date,
    gameMode: GameMode,
    id: Id,
    language: Language,
    moves: Moves,
    playerId: Player.Id,
    puzzle: ArchivablePuzzle
  ) {
    self.code = code
    self.createdAt = createdAt
    self.id = id
    self.language = language
    self.moves = moves
    self.gameMode = gameMode
    self.playerId = playerId
    self.puzzle = puzzle
  }
}
