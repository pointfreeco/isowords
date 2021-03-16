import SharedModels

public enum GameContext: Codable, Equatable {
  case dailyChallenge(DailyChallenge.Id)
  case shared(SharedGame.Code)
  case solo
  case turnBased(TurnBasedContext)

  public var completedGameContext: CompletedGame.GameContext {
    switch self {
    case let .dailyChallenge(id):
      return .dailyChallenge(id)
    case let .shared(code):
      return .shared(code)
    case .solo:
      return .solo
    case let .turnBased(context):
      return .turnBased(playerIndexToId: context.metadata.playerIndexToId)
    }
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    for key in CodingKeys.allCases {
      switch key {
      case .dailyChallengeId where container.contains(key):
        self = try .dailyChallenge(
          container.decode(DailyChallenge.Id.self, forKey: .dailyChallengeId)
        )
        return
      case .sharedGameCode where container.contains(key):
        self = try .shared(container.decode(SharedGame.Code.self, forKey: .sharedGameCode))
        return
      case .turnBased where container.contains(key):
        assertionFailure("Can't decode GameContext.turnBasedGame")
        throw DecodingError.dataCorruptedError(
          forKey: .turnBased,
          in: container,
          debugDescription: "Can't decode GameContext.turnBasedGame"
        )
      case .solo where container.contains(key):
        self = .solo
        return
      case .dailyChallengeId, .sharedGameCode, .solo, .turnBased:
        break
      }
    }

    // If we can't find any of the keys then assume a solo game.
    self = .solo
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)

    switch self {
    case let .dailyChallenge(id):
      try container.encode(id, forKey: .dailyChallengeId)
    case let .shared(code):
      try container.encode(code, forKey: .sharedGameCode)
    case .solo:
      try container.encode(true, forKey: .solo)
    case .turnBased:
      throw EncodingError.invalidValue(
        self,
        .init(
          codingPath: container.codingPath,
          debugDescription: "Can't encode GameContext.turnBasedGame"
        )
      )
    }
  }

  public var isTurnBased: Bool {
    guard case .turnBased = self else { return false }
    return true
  }

  private enum CodingKeys: CaseIterable, CodingKey {
    case dailyChallengeId
    case sharedGameCode
    case solo
    case turnBased
  }
}
