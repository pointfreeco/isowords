public enum SubmitGameResponse: Codable, Equatable {
  case dailyChallenge(DailyChallengeResult)
  case shared(SharedGameResponse)
  case solo(LeaderboardScoreResult)
  case turnBased

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    if container.allKeys.contains(.dailyChallenge) {
      self = .dailyChallenge(
        try container.decode(DailyChallengeResult.self, forKey: .dailyChallenge))
    } else if container.allKeys.contains(.shared) {
      self = .shared(try container.decode(SharedGameResponse.self, forKey: .shared))
    } else if container.allKeys.contains(.solo) {
      self = .solo(try container.decode(LeaderboardScoreResult.self, forKey: .solo))
    } else if container.allKeys.contains(.turnBased),
      try container.decode(Bool.self, forKey: .turnBased)
    {
      self = .turnBased
    } else {
      throw
        DecodingError
        .dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Data corrupted"))
    }
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    switch self {
    case let .dailyChallenge(dailyChallengeResult):
      try container.encode(dailyChallengeResult, forKey: .dailyChallenge)
    case let .shared(sharedResult):
      try container.encode(sharedResult, forKey: .shared)
    case let .solo(leaderboardResult):
      try container.encode(leaderboardResult, forKey: .solo)
    case .turnBased:
      try container.encode(true, forKey: .turnBased)
    }
  }

  private enum CodingKeys: CodingKey {
    case dailyChallenge
    case shared
    case solo
    case turnBased
  }
}

public struct LeaderboardScoreResult: Codable, Equatable {
  public let ranks: [String: Rank]

  public struct Rank: Codable, Equatable {
    public let outOf: Int
    public let rank: Int

    public init(
      outOf: Int,
      rank: Int
    ) {
      self.outOf = outOf
      self.rank = rank
    }
  }

  public init(ranks: [TimeScope: Rank]) {
    self.ranks = Dictionary(
      ranks.map { key, value in (key.rawValue, value) },
      uniquingKeysWith: { $1 }
    )
  }

  public var ranksByTimeScope: [TimeScope: Rank] {
    var result: [TimeScope: Rank] = [:]
    self.ranks.forEach { key, rank in
      guard let timeScope = TimeScope(rawValue: key)
      else { return }
      result[timeScope] = rank
    }
    return result
  }
}
