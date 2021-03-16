public struct FetchVocabWordResponse: Codable, Equatable {
  public let moveIndex: Int
  public let moves: Moves
  public let playerDisplayName: String?
  public let playerId: Player.Id
  public let puzzle: ArchivablePuzzle
}
