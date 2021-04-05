#if DEBUG
  import ClientModels
  import ComposableGameCenter
  import Foundation
  import Overture

  extension TurnBasedMatch {
    public static let inProgress = update(new) {
      $0.matchData = try! JSONEncoder().encode(
        TurnBasedMatchData(
          cubes: .mock,
          gameMode: .unlimited,
          language: .en,
          metadata: .init(lastOpenedAt: nil, playerIndexToId: [:]),
          moves: []
        )
      )
    }

    public static let forfeited = update(inProgress) {
      $0.currentParticipant?.player = .remote
      $0.participants = [
        update(.local) { $0.matchOutcome = .quit },
        .remote,
      ]
    }
  }
#endif
