import Tagged

// NB: These extension need to live in a separate file from where the
//     '@CasePathable enum ServerRoute.Api.Route' macro expands to avoid a 'circular reference'
//     error, or they need to be defined inline and not in extensions.

extension ServerRoute.Api.Route.Games.SubmitRequest {
  public init?(
    completedGame: CompletedGame
  ) {
    switch completedGame.gameContext {
    case let .dailyChallenge(id):
      self.init(gameContext: .dailyChallenge(id), moves: completedGame.moves)

    case let .shared(code):
      self.init(gameContext: .shared(code), moves: completedGame.moves)

    case .solo:
      self.init(
        gameContext: .solo(
          .init(
            gameMode: completedGame.gameMode,
            language: completedGame.language,
            puzzle: completedGame.cubes
          )
        ),
        moves: completedGame.moves
      )

    case let .turnBased(playerIndexToId):
      self.init(
        gameContext: .turnBased(
          .init(
            gameMode: completedGame.gameMode,
            language: completedGame.language,
            playerIndexToId: playerIndexToId,
            puzzle: completedGame.cubes
          )
        ),
        moves: completedGame.moves
      )
    }
  }
}

extension ServerRoute.Api.Route.Games.SubmitRequest.GameContext.TurnBased {
  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.gameMode = try container.decode(GameMode.self, forKey: .gameMode)
    self.language = try container.decode(Language.self, forKey: .language)
    self.playerIndexToId =
      try container
      .decode([Int: Player.Id].self, forKey: .playerIndexToId)
      .transformKeys(Tagged.init(rawValue:))
    self.puzzle = try container.decode(ArchivablePuzzle.self, forKey: .puzzle)
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(self.gameMode, forKey: .gameMode)
    try container.encode(self.language, forKey: .language)
    try container
      .encode(self.playerIndexToId.transformKeys(\.rawValue), forKey: .playerIndexToId)
    try container.encode(self.puzzle, forKey: .puzzle)
  }

  private enum CodingKeys: CodingKey {
    case gameMode
    case language
    case playerIndexToId
    case puzzle
  }
}

extension ServerRoute.Api.Route.Games.SubmitRequest.GameContext {
  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    if container.contains(.dailyChallengeId) {
      self = .dailyChallenge(
        try container.decode(
          SharedModels.DailyChallenge.Id.self, forKey: .dailyChallengeId)
      )
    } else if container.contains(.sharedGameCode) {
      self = .shared(
        try container.decode(SharedModels.SharedGame.Code.self, forKey: .sharedGameCode))
    } else if container.contains(.solo) {
      self = .solo(try container.decode(Solo.self, forKey: .solo))
    } else if container.contains(.turnBased) {
      self = .turnBased(try container.decode(TurnBased.self, forKey: .turnBased))
    } else {
      throw DecodingError.dataCorrupted(
        .init(codingPath: decoder.codingPath, debugDescription: "Data corrupted")
      )
    }
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)

    switch self {
    case let .dailyChallenge(id):
      try container.encode(id, forKey: .dailyChallengeId)
    case let .shared(code):
      try container.encode(code, forKey: .sharedGameCode)
    case let .solo(solo):
      try container.encode(solo, forKey: .solo)
    case let .turnBased(turnBased):
      try container.encode(turnBased, forKey: .turnBased)
    }
  }

  private enum CodingKeys: CodingKey {
    case dailyChallengeId
    case sharedGameCode
    case solo
    case turnBased
  }
}
