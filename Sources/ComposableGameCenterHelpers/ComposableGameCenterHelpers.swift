import ComposableArchitecture
import ComposableGameCenter

public func forceQuitMatch(
  match: TurnBasedMatch,
  gameCenter: GameCenterClient
) -> Effect<Never, Never> {
  let localPlayer = gameCenter.localPlayer.localPlayer()
  let currentParticipantIsLocalPlayer =
    match.currentParticipant?.player?.gamePlayerId == localPlayer.gamePlayerId

  if currentParticipantIsLocalPlayer {
    return gameCenter.turnBasedMatch
      .endMatchInTurn(
        .init(
          for: match.matchId,
          matchData: match.matchData ?? Data(),
          localPlayerId: localPlayer.gamePlayerId,
          localPlayerMatchOutcome: .quit,
          message: "\(localPlayer.displayName) forfeited the match."
        )
      )
      .fireAndForget()
  } else {
    return gameCenter.turnBasedMatch
      .participantQuitOutOfTurn(match.matchId)
      .fireAndForget()
  }
}
