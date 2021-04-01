import ComposableGameCenter
import Foundation
import SharedModels
import Tagged

public struct TurnBasedMatchData: Codable, Equatable {
  public var cubes: ArchivablePuzzle
  public var gameMode: GameMode
  public var language: Language
  public var metadata: Metadata
  public var moves: Moves

  public init(
    cubes: ArchivablePuzzle,
    gameMode: GameMode,
    language: Language,
    metadata: Metadata,
    moves: Moves
  ) {
    self.cubes = cubes
    self.gameMode = gameMode
    self.language = language
    self.metadata = metadata
    self.moves = moves
  }

  public struct Metadata: Codable, Equatable {
    public var playerIndexToId: [SharedModels.Move.PlayerIndex: SharedModels.Player.Id]
    public var wasLastMoveObserved: Bool

    public init(
      playerIndexToId: [SharedModels.Move.PlayerIndex: SharedModels.Player.Id],
      wasLastMoveObserved: Bool
    ) {
      self.playerIndexToId = playerIndexToId
      self.wasLastMoveObserved = wasLastMoveObserved
    }
  }

  public func score(forPlayerIndex index: Move.PlayerIndex) -> Int {
    self.moves.reduce(into: 0) {
      $0 += $1.playerIndex == index ? $1.score : 0
    }
  }

  public typealias Reaction = Move.Reaction
}

extension Data {
  public init(turnBasedMatchData: TurnBasedMatchData) {
    self = try! Self.matchEncoder.encode(turnBasedMatchData)
  }

  public var turnBasedMatchData: TurnBasedMatchData? {
    guard !self.isEmpty else { return nil }
    return try? Self.matchDecoder.decode(TurnBasedMatchData.self, from: self)
  }

  static let matchDecoder = JSONDecoder()
  static let matchEncoder = JSONEncoder()
}

extension TurnBasedMatchData.Metadata {
  private enum CodingKeys: CaseIterable, CodingKey {
    case playerIndexToId
    case wasLastMoveObserved
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    self.playerIndexToId = try container.decode(
      [Int: SharedModels.Player.Id].self,
      forKey: .playerIndexToId
    )
    .transformKeys(Tagged.init(rawValue:))
    
    self.wasLastMoveObserved = try container
      .decodeIfPresent(Bool.self, forKey: .wasLastMoveObserved)
      ?? false
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)

    try container.encode(self.playerIndexToId.transformKeys(\.rawValue), forKey: .playerIndexToId)
  }
}

extension Dictionary {
  func transformKeys<NewKey>(_ f: (Key) -> NewKey) -> [NewKey: Value] {
    var result: [NewKey: Value] = [:]
    for (key, value) in self {
      result[f(key)] = value
    }
    return result
  }
}
