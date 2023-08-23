import ApiClient
import ComposableArchitecture
import GameOverFeature
import Overture
import SharedModels
import Styleguide
import SwiftUI

@main
struct GameOverPreviewApp: App {
  init() {
    Styleguide.registerFonts()
  }

  var body: some Scene {
    WindowGroup {
      GameOverView(
        store: .solo
          // store: .multiplayer
      )
    }
  }
}

extension StoreOf<GameOver> {
  static var solo: Self {
    Self(
      initialState: .init(
        completedGame: .init(
          cubes: .mock,
          gameContext: .solo,
          gameMode: .unlimited,
          gameStartTime: .mock,
          language: .en,
          moves: .init((1...7).map { _ in .highScoringMove }),
          secondsPlayed: 0
        ),
        isDemo: false
      )
    ) {
      GameOver()
    } withDependencies: {
      $0.apiClient = update(.noop) {
        $0.override(
          routeCase: (/ServerRoute.Api.Route.games)
            .appending(path: /ServerRoute.Api.Route.Games.submit),
          withResponse: { _ in
            try await OK(
              SubmitGameResponse.solo(
                .init(
                  ranks: [
                    .allTime: .init(outOf: 152122, rank: 3828),
                    .lastDay: .init(outOf: 512, rank: 79),
                    .lastWeek: .init(outOf: 1603, rank: 605),
                  ]
                )
              )
            )
          }
        )
      }
      $0.audioPlayer = .noop
      $0.database = .autoMigratingLive(
        path: FileManager.default
          .urls(for: .documentDirectory, in: .userDomainMask)
          .first!
          .appendingPathComponent("co.pointfree.Isowords")
          .appendingPathComponent("Isowords.sqlite3")
      )
      $0.fileClient = .noop
      $0.remoteNotifications = .noop
      $0.serverConfig = .noop
      $0.userDefaults.boolForKey = { _ in false }
      $0.userNotifications = .noop
    }
  }

  static var multiplayer: Self {
    Self(
      initialState: GameOver.State(
        completedGame: .turnBased,
        isDemo: false,
        summary: nil,
        turnBasedContext: .init(
          localPlayer: .mock,
          match: update(.mock) {
            $0.participants = [
              update(.local) { $0.matchOutcome = .won },
              update(.remote) { $0.matchOutcome = .lost },
            ]
          },
          metadata: .init(lastOpenedAt: nil, playerIndexToId: [:])
        )
      )
    ) {
      GameOver()
    } withDependencies: {
      $0.context = .preview
    }
  }
}
