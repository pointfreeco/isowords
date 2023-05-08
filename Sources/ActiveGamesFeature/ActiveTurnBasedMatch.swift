import AnyComparable
import ClientModels
import ComposableArchitecture
import ComposableGameCenter
import GameKit
import SharedModels
import Tagged
import TcaHelpers

public struct ActiveTurnBasedMatch: Equatable, Identifiable {
  public let id: ComposableGameCenter.TurnBasedMatch.Id
  public let isStale: Bool
  public let isYourTurn: Bool
  public let lastPlayedAt: Date
  public let playedWord: PlayedWord?
  public let status: GKTurnBasedMatch.Status
  public let theirIndex: Move.PlayerIndex?
  public let theirName: String?

  public init(
    id: ComposableGameCenter.TurnBasedMatch.Id,
    isYourTurn: Bool,
    lastPlayedAt: Date,
    now: Date,
    playedWord: PlayedWord?,
    status: GKTurnBasedMatch.Status,
    theirIndex: Move.PlayerIndex?,
    theirName: String?
  ) {
    self.id = id
    self.isStale = now.timeIntervalSince(lastPlayedAt) > 60 * 60 * 24
    self.isYourTurn = isYourTurn
    self.lastPlayedAt = lastPlayedAt
    self.playedWord = playedWord
    self.status = status
    self.theirIndex = theirIndex
    self.theirName = theirName
  }
}

extension ActiveTurnBasedMatch: Comparable {
  public static func < (lhs: ActiveTurnBasedMatch, rhs: ActiveTurnBasedMatch) -> Bool {
    func trueFirst(_ lhs: Bool, _ rhs: Bool) -> Bool { lhs }

    return (
      AnyComparable(lhs.status.rawValue).reversed,
      AnyComparable(lhs.isYourTurn, compare: trueFirst),
      AnyComparable(lhs.lastPlayedAt).reversed
    )
      < (
        AnyComparable(rhs.status.rawValue).reversed,
        AnyComparable(rhs.isYourTurn, compare: trueFirst),
        AnyComparable(rhs.lastPlayedAt).reversed
      )
  }
}

extension ActiveTurnBasedMatch {
  public init(
    context: TurnBasedContext,
    matchData: TurnBasedMatchData,
    now: Date
  ) {
    self.init(
      id: context.match.matchId,
      isYourTurn: context.currentParticipantIsLocalPlayer,
      lastPlayedAt: context.lastPlayedAt,
      now: now,
      playedWord: matchData.moves
        .last(where: { (/Move.MoveType.playedWord).isMatching($0.type) })
        .flatMap { move in
          guard
            let playerIndex = move.playerIndex,
            case let .playedWord(indices) = move.type
          else { return nil }

          return PlayedWord(
            isYourWord: playerIndex == context.localPlayerIndex,
            reactions: move.reactions,
            score: move.score,
            word: matchData.cubes.string(from: indices)
          )
        },
      status: context.match.status,
      theirIndex: context.otherPlayerIndex,
      theirName: context.otherPlayer?.displayName
    )
  }
}

extension ActiveTurnBasedMatch {
  public init?(match: TurnBasedMatch, localPlayer: LocalPlayer, now: Date) {
    guard
      let data = match.matchData,
      !data.isEmpty,
      let turnBasedMatchData = data.turnBasedMatchData
    else { return nil }

    self.init(
      context: .init(localPlayer: localPlayer, match: match, metadata: turnBasedMatchData.metadata),
      matchData: turnBasedMatchData,
      now: now
    )
  }
}

extension Array where Element == TurnBasedMatch {
  public func activeMatches(
    for localPlayer: LocalPlayer,
    at date: Date
  ) -> [ActiveTurnBasedMatch] {
    self
      .filter { $0.status == .open && $0.participants.allSatisfy { $0.matchOutcome == .none } }
      .compactMap { match in
        ActiveTurnBasedMatch.init(match: match, localPlayer: localPlayer, now: date)
      }
      .sorted()
  }
}
