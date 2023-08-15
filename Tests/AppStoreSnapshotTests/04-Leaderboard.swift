import ComposableArchitecture
import LeaderboardFeature
import Overture
import SharedModels
import SwiftUI

var leaderboardAppStoreView: AnyView {
  let view = LeaderboardView(
    store: Store(
      initialState: Leaderboard.State(
        cubePreview: nil,
        isAnimationReduced: false,
        isHapticsEnabled: true,
        scope: .vocab,
        settings: .init(),
        solo: LeaderboardResults.State(
          gameMode: .unlimited,
          isLoading: false,
          isTimeScopeMenuVisible: false,
          resultEnvelope: ResultEnvelope(
            outOf: 0,
            results: []
          ),
          timeScope: .lastWeek
        ),
        vocab: LeaderboardResults.State(
          gameMode: .unlimited,
          isLoading: false,
          isTimeScopeMenuVisible: false,
          resultEnvelope: ResultEnvelope(
            outOf: 332_380,
            results: .snapshot
          ),
          timeScope: .lastWeek
        )
      )
    ) {
      
    }
  )
  return AnyView(view)
}

extension Array where Element == ResultEnvelope.Result {
  static let snapshot: [ResultEnvelope.Result] = [
    .init(
      denseRank: 1,
      id: .init(),
      isYourScore: false,
      rank: 1,
      score: 1_680,
      subtitle: "junebash",
      title: "Inquisitor"
    ),
    .init(
      denseRank: 2,
      id: .init(),
      isYourScore: false,
      rank: 2,
      score: 1_120,
      subtitle: "ryanbooker",
      title: "Traditions"
    ),
    .init(
      denseRank: 3,
      id: .init(),
      isYourScore: false,
      rank: 3,
      score: 920,
      subtitle: "stephen",
      title: "Queening"
    ),
    .init(
      denseRank: 4,
      id: .init(),
      isYourScore: true,
      rank: 4,
      score: 880,
      subtitle: "You",
      title: "Quintile"
    ),
    .init(
      denseRank: 5,
      id: .init(),
      isYourScore: false,
      rank: 4,
      score: 880,
      subtitle: "Connoljoff",
      title: "Quintile"
    ),
    .init(
      denseRank: 6,
      id: .init(),
      isYourScore: false,
      rank: 4,
      score: 880,
      subtitle: "junebash",
      title: "Quintile"
    ),
    .init(
      denseRank: 7,
      id: .init(),
      isYourScore: false,
      rank: 7,
      score: 864,
      subtitle: "Connoljoff",
      title: "Renouncer"
    ),
    .init(
      denseRank: 8,
      id: .init(),
      isYourScore: false,
      rank: 7,
      score: 864,
      subtitle: "-jcoono-",
      title: "Renouncer"
    ),
    .init(
      denseRank: 9,
      id: .init(),
      isYourScore: false,
      rank: 9,
      score: 840,
      subtitle: "vunt",
      title: "Explains"
    ),
    .init(
      denseRank: 10,
      id: .init(),
      isYourScore: false,
      rank: 9,
      score: 840,
      subtitle: "robsr 47",
      title: "Unequals"
    ),
    .init(
      denseRank: 11,
      id: .init(),
      isYourScore: false,
      rank: 9,
      score: 840,
      subtitle: "eDickC",
      title: "Unequals"
    ),
    .init(
      denseRank: 12,
      id: .init(),
      isYourScore: false,
      rank: 12,
      score: 760,
      subtitle: "stephencelis",
      title: "Sextette"
    ),
    .init(
      denseRank: 13,
      id: .init(),
      isYourScore: false,
      rank: 12,
      score: 760,
      subtitle: "robsr 47",
      title: "Textiles"
    ),
    .init(
      denseRank: 14,
      id: .init(),
      isYourScore: false,
      rank: 12,
      score: 760,
      subtitle: "stephencelis",
      title: "Textiles"
    )
  ]
}
