import ApiClient
import CasePaths
import ComposableArchitecture
import LeaderboardFeature
import Overture
import SharedModels
import Styleguide
import SwiftUI

@main
struct LeaderboardsPreviewApp: App {
  init() {
    Styleguide.registerFonts()
  }

  var body: some Scene {
    var apiClient = ApiClient.noop
    apiClient.override(
      route: .leaderboard(
        .fetch(
          gameMode: .timed,
          language: .en,
          timeScope: .lastWeek
        )
      ),
      withResponse: {
        try await OK(
          FetchLeaderboardResponse(
            entries: (1...20).map { index in
              .init(
                id: .init(rawValue: UUID()),
                isSupporter: false,
                isYourScore: false,
                outOf: 2_000,
                playerDisplayName: "Blob \(index)",
                rank: index,
                score: 4_000 - index * 100
              )
            }
              + [
                .init(
                  id: .init(rawValue: UUID()),
                  isSupporter: false,
                  isYourScore: true,
                  outOf: 2_000,
                  playerDisplayName: "Blob Sr.",
                  rank: 100,
                  score: 1_000
                )
              ]
          )
        )
      }
    )

    return WindowGroup {
      LeaderboardView(
        store: Store(initialState: Leaderboard.State(isHapticsEnabled: false, settings: .init())) {
          Leaderboard()
        } withDependencies: {
          $0.apiClient = apiClient
          $0.audioPlayer = .noop
          $0.feedbackGenerator = .noop
          $0.lowPowerMode = .false
        }
      )
    }
  }
}
