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
//        store: .multiplayer
      )
    }
  }
}

extension Store where State == GameOverState, Action == GameOverAction {
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
      ),
      reducer: gameOverReducer,
      environment: .init(
        apiClient: update(.noop) {
          $0.override(
            routeCase: (/ServerRoute.Api.Route.games)
              .appending(path: /ServerRoute.Api.Route.Games.submit),
            withResponse: { _ in
              Effect.ok(
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
              .delay(for: 1, scheduler: DispatchQueue.main)
              .eraseToEffect()
            }
          )
        },
        audioPlayer: .noop,
        database: .autoMigratingLive(
          path: FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent("co.pointfree.Isowords")
            .appendingPathComponent("Isowords.sqlite3")
        ),
        fileClient: .noop,
        mainQueue: .main,
        mainRunLoop: .main,
        remoteNotifications: .noop,
        serverConfig: .noop,
        storeKit: .live(),
        userDefaults: update(.live()) {
          $0.boolForKey = { _ in false }
        },
        userNotifications: .noop
      )
    )
  }

  static var multiplayer: Self {
    Self(
      initialState: .init(
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
      ),
      reducer: gameOverReducer,
      environment: .preview
    )
  }
}
