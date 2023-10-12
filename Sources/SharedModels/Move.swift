import CasePaths
import Foundation
import Tagged

public struct Move: Codable, Equatable, Sendable {
  public var playedAt: Date
  public var playerIndex: PlayerIndex?
  public var reactions: [PlayerIndex: Reaction]?
  public var score: Int
  public var type: MoveType

  public typealias PlayerIndex = Tagged<Move, Int>

  public init(
    playedAt: Date,
    playerIndex: PlayerIndex?,
    reactions: [PlayerIndex: Reaction]?,
    score: Int,
    type: MoveType
  ) {
    self.playedAt = playedAt
    self.playerIndex = playerIndex
    self.reactions = reactions
    self.score = score
    self.type = type
  }

  @CasePathable
  public enum MoveType: Codable, Equatable, Sendable {
    case playedWord([IndexedCubeFace])
    case removedCube(LatticePoint)

    public init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      if container.contains(.playedWord) {
        let playedWord = try container.decode([IndexedCubeFace].self, forKey: .playedWord)
        self = .playedWord(playedWord)
      } else if container.contains(.removedCube) {
        let removedCube = try container.decode(LatticePoint.self, forKey: .removedCube)
        self = .removedCube(removedCube)
      } else {
        throw DecodingError.dataCorrupted(
          .init(codingPath: container.codingPath, debugDescription: "Decoding failed")
        )
      }
    }

    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      switch self {
      case let .playedWord(playedWord):
        try container.encode(playedWord, forKey: .playedWord)
      case let .removedCube(removedCube):
        try container.encode(removedCube, forKey: .removedCube)
      }
    }

    private enum CodingKeys: CodingKey {
      case playedWord
      case removedCube
    }
  }

  public struct Reaction: CaseIterable, Codable, Hashable, Identifiable, RawRepresentable, Sendable
  {
    public let rawValue: String

    public init(rawValue: String) {
      self.rawValue = rawValue
    }

    public static let angel = Self(rawValue: "😇")
    public static let anger = Self(rawValue: "😡")
    public static let sob = Self(rawValue: "😭")
    public static let confused = Self(rawValue: "😕")
    public static let smirk = Self(rawValue: "😏")
    public static let smilingDevil = Self(rawValue: "😈")

    public static let allCases: [Self] = [
      angel,
      anger,
      sob,
      confused,
      smirk,
      smilingDevil,
    ]

    public var id: Self { self }
  }
}

extension Move {
  private enum CodingKeys: CaseIterable, CodingKey {
    case playedAt
    case playerIndex
    case reactions
    case score
    case type
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    self.playedAt = try container.decode(Date.self, forKey: .playedAt)
    self.playerIndex = try container.decodeIfPresent(PlayerIndex.self, forKey: .playerIndex)
    self.reactions = try container.decodeIfPresent([Int: Reaction].self, forKey: .reactions)?
      .transformKeys(Tagged.init(rawValue:))
    self.score = try container.decode(Int.self, forKey: .score)
    self.type = try container.decode(MoveType.self, forKey: .type)
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)

    try container.encode(self.playedAt, forKey: .playedAt)
    try container.encodeIfPresent(self.playerIndex, forKey: .playerIndex)
    try container.encodeIfPresent(self.reactions?.transformKeys(\.rawValue), forKey: .reactions)
    try container.encode(self.score, forKey: .score)
    try container.encode(self.type, forKey: .type)
  }
}

#if DEBUG
  extension Move {
    public static let mock = Self(
      playedAt: .mock,
      playerIndex: nil,
      reactions: nil,
      score: 20,
      type: .playedWord([
        .init(index: .init(x: .two, y: .two, z: .two), side: .left),
        .init(index: .init(x: .two, y: .two, z: .two), side: .right),
        .init(index: .init(x: .two, y: .two, z: .two), side: .top),
      ])
    )

    public static let cab = Self(
      playedAt: .mock,
      playerIndex: nil,
      reactions: nil,
      score: SharedModels.score("CAB"),
      type: .playedWord([
        .init(index: .init(x: .two, y: .two, z: .two), side: .top),
        .init(index: .init(x: .two, y: .two, z: .two), side: .left),
        .init(index: .init(x: .two, y: .two, z: .two), side: .right),
      ])
    )

    public static let removeCube = Self(
      playedAt: .mock,
      playerIndex: nil,
      reactions: nil,
      score: 0,
      type: .removedCube(.init(x: .two, y: .two, z: .two))
    )

    public static let highScoringMove = Self(
      playedAt: .mock,
      playerIndex: nil,
      reactions: nil,
      score: 1_234,
      type: .playedWord([
        .init(index: .init(x: .two, y: .two, z: .two), side: .left),
        .init(index: .init(x: .two, y: .two, z: .two), side: .right),
        .init(index: .init(x: .two, y: .two, z: .two), side: .top),
      ])
    )

    public static func playedWord(length: Int) -> Self {
      Self(
        playedAt: .mock,
        playerIndex: nil,
        reactions: nil,
        score: 1_234,
        type: .playedWord(
          (1...length).map { _ in
            .init(index: .init(x: .two, y: .two, z: .two), side: .left)
          }
        )
      )
    }
  }
#endif
