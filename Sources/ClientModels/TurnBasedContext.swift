import ComposableGameCenter
import Foundation
import SharedModels
import Tagged

public struct TurnBasedContext: Equatable {
  public var localPlayer: LocalPlayer
  public var match: TurnBasedMatch
  public var metadata: TurnBasedMatchData.Metadata

  public init(
    localPlayer: LocalPlayer,
    match: TurnBasedMatch,
    metadata: TurnBasedMatchData.Metadata
  ) {
    self.localPlayer = localPlayer
    self.match = match
    self.metadata = metadata
  }

  public var currentParticipantIsLocalPlayer: Bool {
    match.currentParticipant?.player?.gamePlayerId == localPlayer.gamePlayerId
  }

  public var lastPlayedAt: Date {
    match.participants.lazy.compactMap(\.lastTurnDate).max() ?? match.creationDate
  }

  public var localParticipant: TurnBasedParticipant? {
    match.participants
      .first { $0.player?.gamePlayerId == localPlayer.gamePlayerId }
  }

  public var localPlayerIndex: Move.PlayerIndex? {
    match.participants
      .firstIndex(where: { $0.player?.gamePlayerId == localPlayer.gamePlayerId })
      .map(Tagged.init(rawValue:))
  }

  public var otherParticipant: TurnBasedParticipant? {
    match.participants
      .first { $0.player?.gamePlayerId != localPlayer.gamePlayerId }
  }

  public var otherPlayer: ComposableGameCenter.Player? {
    otherParticipant?.player
  }

  public var otherPlayerIndex: Move.PlayerIndex? {
    match.participants
      .firstIndex { $0.player?.gamePlayerId != localPlayer.gamePlayerId }
      .map(Tagged.init(rawValue:))
  }
}
