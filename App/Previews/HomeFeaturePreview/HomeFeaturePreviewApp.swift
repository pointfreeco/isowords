import ApiClient
import ComposableArchitecture
import Overture
import SharedModels
import Styleguide
import SwiftUI

@testable import HomeFeature

@main
struct HomeFeaturePreviewApp: App {
  init() {
    Styleguide.registerFonts()
  }

  var body: some Scene {
    WindowGroup {
      NavigationView {
        HomeView(
          store: Store(
            initialState: Home.State(),
            reducer: Home()
              .dependency(
                \.apiClient,
                update(.noop) {
                  $0.authenticate = { _ in .init(appleReceipt: nil, player: .blob) }
                  $0.override(
                    route: .dailyChallenge(.today(language: .en)),
                    withResponse: {
                      try await OK([
                        FetchTodaysDailyChallengeResponse(
                          dailyChallenge: .init(
                            endsAt: .init(),
                            gameMode: .timed,
                            id: .init(rawValue: UUID()),
                            language: .en
                          ),
                          yourResult: .init(
                            outOf: .random(in: 2000...4000),
                            rank: 10,
                            score: 3_000
                          )
                        )
                      ])
                    }
                  )
                }
              )
              .dependency(\.applicationClient, .noop)
              .dependency(\.audioPlayer, .noop)
              .dependency(\.build, .noop)
              .dependency(\.database, .inMemory)
              .dependency(\.deviceId, .noop)
              .dependency(\.gameCenter, .noop)
              .dependency(\.remoteNotifications, .noop)
              .dependency(\.serverConfig, .noop)
              .dependency(\.storeKit, .noop)
              .dependency(\.userDefaults, .noop)
              .dependency(\.userNotifications, .noop)
          )
        )
      }
    }
  }
}
