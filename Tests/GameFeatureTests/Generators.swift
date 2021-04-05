import ClientModels
import ComposableGameCenter
import GameFeature
import GameKit
import Gen
import PuzzleGen
import SharedModels

extension Gen where Value == UUID {
  static var uuid: Gen {
    let hex = Gen<Character?>
      .element(
        of: ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "a", "b", "c", "d", "e", "f"]
      )
      .map { $0! }

    return zip(
      hex.string(of: .always(8)),
      hex.string(of: .always(4)),
      hex.string(of: .always(4)),
      hex.string(of: .always(4)),
      hex.string(of: .always(12))
    )
    .map { UUID(uuidString: "\($0)-\($1)-\($2)-\($3)-\($4)")! }
  }
}

extension Gen where Value == Date {
  static let date = always(.mock)
}

extension Gen where Value == DailyChallenge.Id {
  static let dailyChallengeId = Gen<UUID>.uuid.map(DailyChallenge.Id.init(rawValue:))
}

extension Gen where Value == IndexedCubeFace {
  static let indexedCubeFace = zip(
    .latticePoint,
    .allCases
  )
  .map(IndexedCubeFace.init(index:side:))
}

extension Gen where Value == LatticePoint {
  static let latticePoint = zip(
    Gen<LatticePoint.Index>.allCases,
    Gen<LatticePoint.Index>.allCases,
    Gen<LatticePoint.Index>.allCases
  )
  .map(LatticePoint.init(x:y:z:))
}

extension Gen where Value == Move.MoveType {
  static let moveType = Gen.frequency(
    (5, .playedWord),
    (1, .removedCube)
  )

  static let playedWord = Gen<IndexedCubeFace>.indexedCubeFace
    .array(of: .int(in: 1...10))
    .map(Value.playedWord)

  static let removedCube = Gen<LatticePoint>.latticePoint
    .map(Value.removedCube)
}

extension Gen where Value == Move {
  static let move = zip(
    .date,
    .frequency(
      (2, .always(nil)),
      (1, .element(of: [0, 1]))
    ),
    zip(Gen<Move.PlayerIndex?>.element(of: [0, 1]), Gen<Move.Reaction>.allCases).map { [$0!: $1] },
    .int(in: 0...1000),
    .moveType
  )
  .map(Move.init(playedAt:playerIndex:reactions:score:type:))
}

extension Gen where Value == LocalPlayer {
  static let localPlayer = zip(
    .bool,
    .bool,
    .player
  ).map {
    LocalPlayer(
      isAuthenticated: $0,
      isMultiplayerGamingRestricted: $1,
      player: $2
    )
  }
}

extension Gen where Value == TurnBasedMatchData.Metadata {
}

extension Gen where Value == TurnBasedContext {
  static let turnBasedContext = zip(
    .localPlayer,
    .turnBasedMatch,
    .always(.init(lastOpenedAt: nil, playerIndexToId: [:]))
  )
  .map {
    TurnBasedContext(
      localPlayer: $0,
      match: $1,
      metadata: $2
    )
  }
}

extension Gen where Value == GameState {
  static let gameState = zip(
    randomCubes(for: isowordsLetter),
    .frequency(
      (1, .always(.solo)),
      (1, Gen<DailyChallenge.Id>.dailyChallengeId.map(GameContext.dailyChallenge)),
      (1, Gen<TurnBasedContext>.turnBasedContext.map(GameContext.turnBased))
    ),
    .date,
    .allCases,
    .date,
    Gen<Move>.move.array(of: .int(in: 0...30)).map(Moves.init)
  )
  .map {
    GameState(
      cubes: $0,
      gameContext: $1,
      gameCurrentTime: $2,
      gameMode: $3,
      gameStartTime: $4,
      moves: $5
    )
  }
}

extension Gen where Value == ComposableGameCenter.Player {
  static let player = zip(
    Gen<Character>.letter.string(of: .int(in: 3...10)),
    Gen<Character>.letter.string(of: .int(in: 3...10)),
    Gen<Character>.letter.string(of: .int(in: 3...10)).map(
      ComposableGameCenter.Player.Id.init(rawValue:))
  )
  .map {
    ComposableGameCenter.Player(
      alias: $0,
      displayName: $1,
      gamePlayerId: $2
    )
  }
}

extension Gen where Value == TurnBasedParticipant {
  static let turnBasedParticipant = zip(
    Gen<Date>.date.optional,
    .frequency(
      (1, .always(GKTurnBasedMatch.Outcome.first)),
      (1, .always(GKTurnBasedMatch.Outcome.lost)),
      (1, .always(GKTurnBasedMatch.Outcome.none)),
      (1, .always(GKTurnBasedMatch.Outcome.quit)),
      (1, .always(GKTurnBasedMatch.Outcome.second)),
      (1, .always(GKTurnBasedMatch.Outcome.tied)),
      (1, .always(GKTurnBasedMatch.Outcome.timeExpired)),
      (1, .always(GKTurnBasedMatch.Outcome.won))
    ),
    Gen<ComposableGameCenter.Player>.player.optional,
    .frequency(
      (1, .always(GKTurnBasedParticipant.Status.active)),
      (1, .always(GKTurnBasedParticipant.Status.declined)),
      (1, .always(GKTurnBasedParticipant.Status.done)),
      (1, .always(GKTurnBasedParticipant.Status.invited)),
      (1, .always(GKTurnBasedParticipant.Status.matching)),
      (1, .always(GKTurnBasedParticipant.Status.unknown))
    ),
    Gen<Date>.date.optional
  )
  .map {
    TurnBasedParticipant(
      lastTurnDate: $0,
      matchOutcome: $1,
      player: $2,
      status: $3,
      timeoutDate: $4
    )
  }
}

extension Gen where Value == TurnBasedMatch {
  static let turnBasedMatch = zip(
    .date,
    Gen<TurnBasedParticipant>.turnBasedParticipant.optional,
    Gen<Data?>.always(nil),
    Gen<Character>.letter.string(of: .int(in: 3...10)).map(TurnBasedMatch.Id.init(rawValue:)),
    Gen<TurnBasedParticipant>.turnBasedParticipant.array(of: .always(2)),
    .frequency(
      (1, .always(GKTurnBasedMatch.Status.ended)),
      (1, .always(GKTurnBasedMatch.Status.matching)),
      (1, .always(GKTurnBasedMatch.Status.open)),
      (1, .always(GKTurnBasedMatch.Status.unknown))
    )
  ).map {
    TurnBasedMatch(
      creationDate: $0,
      currentParticipant: $1,
      matchData: $2,
      matchId: $3,
      participants: $4,
      status: $5
    )
  }
}
