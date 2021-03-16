import Foundation
import Tagged

public struct SharedGameResponse: Codable, Equatable {
  public let code: SharedGame.Code
  public let id: SharedGame.Id
  public let gameMode: GameMode
  public let language: Language
  public let moves: Moves
  public let puzzle: ArchivablePuzzle

  public init(
    code: SharedGame.Code,
    id: SharedGame.Id,
    gameMode: GameMode,
    language: Language,
    moves: Moves,
    puzzle: ArchivablePuzzle
  ) {
    self.code = code
    self.id = id
    self.gameMode = gameMode
    self.language = language
    self.moves = moves
    self.puzzle = puzzle
  }
}
