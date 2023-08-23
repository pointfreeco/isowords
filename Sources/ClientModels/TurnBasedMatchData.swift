import ComposableGameCenter
import Dependencies
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
    public var lastOpenedAt: Date?
    public var playerIndexToId: [SharedModels.Move.PlayerIndex: SharedModels.Player.Id]

    public init(
      lastOpenedAt: Date?,
      playerIndexToId: [SharedModels.Move.PlayerIndex: SharedModels.Player.Id]
    ) {
      self.lastOpenedAt = lastOpenedAt
      self.playerIndexToId = playerIndexToId
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
  static let matchEncoder: JSONEncoder = {
    let encoder = JSONEncoder()
    // TODO: Would be better to move this JSON decode to its own @Dependency.
    @Dependency(\.context) var context
    if context == .test {
      encoder.outputFormatting = .sortedKeys
    }
    return encoder
  }()
}

extension TurnBasedMatchData.Metadata {
  private enum CodingKeys: CaseIterable, CodingKey {
    case lastOpenedAt
    case playerIndexToId
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    self.playerIndexToId = try container.decode(
      [Int: SharedModels.Player.Id].self,
      forKey: .playerIndexToId
    )
    .transformKeys(Tagged.init(rawValue:))

    self.lastOpenedAt =
      try container
      .decodeIfPresent(Date.self, forKey: .lastOpenedAt)
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)

    try container.encode(self.playerIndexToId.transformKeys(\.rawValue), forKey: .playerIndexToId)
    try container.encodeIfPresent(self.lastOpenedAt, forKey: .lastOpenedAt)
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
