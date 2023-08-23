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
          store: Store(initialState: Home.State()) {
            Home()
          } withDependencies: {
            $0.apiClient = update(.noop) {
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
            $0.applicationClient = .noop
            $0.audioPlayer = .noop
            $0.build = .noop
            $0.database = .inMemory
            $0.deviceId = .noop
            $0.gameCenter = .noop
            $0.remoteNotifications = .noop
            $0.serverConfig = .noop
            $0.storeKit = .noop
            $0.userDefaults = .noop
            $0.userNotifications = .noop
          }
        )
      }
    }
  }
}
