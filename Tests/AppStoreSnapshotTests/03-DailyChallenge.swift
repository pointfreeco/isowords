import ComposableArchitecture
import DailyChallengeFeature
import LeaderboardFeature
import Overture
import SharedModels
import SwiftUI

var dailyChallengeAppStoreView: AnyView {
  let view = DailyChallengeResultsView(
    store: Store<DailyChallengeResultsState, DailyChallengeResultsAction>(
      initialState: DailyChallengeResultsState(
        history: nil,
        leaderboardResults: .init(
          gameMode: .timed,
          isLoading: false,
          isTimeScopeMenuVisible: false,
          resultEnvelope: ResultEnvelope(.snapshot),
          timeScope: nil
        )
      ),
      reducer: .empty,
      environment: ()
    )
  )
  return AnyView(view)
}

extension FetchDailyChallengeResultsResponse {
  static let snapshot = Self(
    results: [
      .init(
        isSupporter: false,
        isYourScore: false,
        outOf: 2_945,
        playerDisplayName: "stephencelis",
        playerId: .init(rawValue: .init()),
        rank: 1,
        score: 2_327
      ),
      .init(
        isSupporter: false,
        isYourScore: true,
        outOf: 2_945,
        playerDisplayName: "mbrandonw",
        playerId: .init(rawValue: .init()),
        rank: 2,
        score: 1_696
      ),
      .init(
        isSupporter: false,
        isYourScore: false,
        outOf: 2_945,
        playerDisplayName: "kmh2021",
        playerId: .init(rawValue: .init()),
        rank: 3,
        score: 1_655
      ),
      .init(
        isSupporter: false,
        isYourScore: false,
        outOf: 2_945,
        playerDisplayName: "twernie",
        playerId: .init(rawValue: .init()),
        rank: 4,
        score: 1_556
      ),
      .init(
        isSupporter: false,
        isYourScore: false,
        outOf: 2_945,
        playerDisplayName: "robsr 47",
        playerId: .init(rawValue: .init()),
        rank: 5,
        score: 1_353
      ),
      .init(
        isSupporter: false,
        isYourScore: false,
        outOf: 2_945,
        playerDisplayName: "Call Me Yanny",
        playerId: .init(rawValue: .init()),
        rank: 6,
        score: 1_126
      ),
      .init(
        isSupporter: false,
        isYourScore: false,
        outOf: 2_945,
        playerDisplayName: "chefnobody",
        playerId: .init(rawValue: .init()),
        rank: 7,
        score: 968
      ),
      .init(
        isSupporter: false,
        isYourScore: false,
        outOf: 2_945,
        playerDisplayName: "smartman 2000",
        playerId: .init(rawValue: .init()),
        rank: 8,
        score: 960
      ),
      .init(
        isSupporter: false,
        isYourScore: false,
        outOf: 2_945,
        playerDisplayName: "lelandr",
        playerId: .init(rawValue: .init()),
        rank: 9,
        score: 943
      ),
      .init(
        isSupporter: false,
        isYourScore: false,
        outOf: 2_945,
        playerDisplayName: "Someone",
        playerId: .init(rawValue: .init()),
        rank: 10,
        score: 925
      ),
      .init(
        isSupporter: false,
        isYourScore: false,
        outOf: 2_945,
        playerDisplayName: "myurieff",
        playerId: .init(rawValue: .init()),
        rank: 11,
        score: 907
      ),
      .init(
        isSupporter: false,
        isYourScore: false,
        outOf: 2_945,
        playerDisplayName: "Wyntermutex",
        playerId: .init(rawValue: .init()),
        rank: 12,
        score: 902
      ),
      .init(
        isSupporter: false,
        isYourScore: false,
        outOf: 2_945,
        playerDisplayName: "simme",
        playerId: .init(rawValue: .init()),
        rank: 13,
        score: 760
      ),
      .init(
        isSupporter: false,
        isYourScore: false,
        outOf: 2_945,
        playerDisplayName: "Someone",
        playerId: .init(rawValue: .init()),
        rank: 14,
        score: 724
      ),
      .init(
        isSupporter: false,
        isYourScore: false,
        outOf: 2_945,
        playerDisplayName: "junebash",
        playerId: .init(rawValue: .init()),
        rank: 15,
        score: 723
      ),
      .init(
        isSupporter: false,
        isYourScore: false,
        outOf: 2_945,
        playerDisplayName: "ryanbooker",
        playerId: .init(rawValue: .init()),
        rank: 16,
        score: 721
      ),
      .init(
        isSupporter: false,
        isYourScore: false,
        outOf: 2_945,
        playerDisplayName: "_maloneh",
        playerId: .init(rawValue: .init()),
        rank: 17,
        score: 678
      ),
      .init(
        isSupporter: false,
        isYourScore: false,
        outOf: 2_945,
        playerDisplayName: "pearapps",
        playerId: .init(rawValue: .init()),
        rank: 18,
        score: 670
      ),
      .init(
        isSupporter: false,
        isYourScore: false,
        outOf: 2_945,
        playerDisplayName: "Kevlario",
        playerId: .init(rawValue: .init()),
        rank: 19,
        score: 615
      ),
      .init(
        isSupporter: false,
        isYourScore: false,
        outOf: 2_945,
        playerDisplayName: "carohodges",
        playerId: .init(rawValue: .init()),
        rank: 20,
        score: 599
      ),
      .init(
        isSupporter: false,
        isYourScore: false,
        outOf: 2_945,
        playerDisplayName: "scibidoo",
        playerId: .init(rawValue: .init()),
        rank: 21,
        score: 540
      ),
    ]
  )
}
