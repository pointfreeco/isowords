import Overture
import Styleguide
import SwiftUI

@testable import GameOverFeature

@main
struct GameOverPreviewApp: App {
  init() {
    Styleguide.registerFonts()
  }

  var body: some Scene {
    WindowGroup {
      //      GameOverView(
      //        store: .init(
      //          initialState: .init(
      //            completedGame: .init(
      //              cubes: .mock,
      //              gameContext: .solo,
      //              gameMode: .unlimited,
      //              gameStartTime: .mock,
      //              language: .en,
      //              moves: [
      //                .highScoringMove,
      //                .highScoringMove,
      //                .highScoringMove,
      //                .highScoringMove,
      //                .highScoringMove,
      //                .highScoringMove,
      //                .highScoringMove,
      //              ],
      //              secondsPlayed: 0
      //            ),
      //            isDemo: false,
      //            summary: .dailyChallenge(
      //              .init(
      //                outOf: 149,
      //                rank: 23,
      //                score: 12491
      //              )
      //            )
      ////            summary: .leaderboard([
      ////              .allTime: .init(outOf: 152122, rank: 3828),
      ////              .lastDay: .init(outOf: 512, rank: 79),
      ////              .lastWeek: .init(outOf: 1603, rank: 605),
      ////            ])
      //          ),
      //          reducer: gameOverReducer,
      //          environment: .init(
      //            apiClient: .noop,
      //            audioPlayer: .noop,
      //            database: .autoMigratingLive(
      //              path: FileManager.default
      //                .urls(for: .documentDirectory, in: .userDomainMask)
      //                .first!
      //                .appendingPathComponent("co.pointfree.Isowords")
      //                .appendingPathComponent("Isowords.sqlite3")
      //            ),
      //            fileClient: .noop,
      //            mainQueue: DispatchQueue.main.eraseToAnyScheduler(),
      //            mainRunLoop: RunLoop.main.eraseToAnyScheduler(),
      //            remoteNotifications: .noop,
      //            serverConfig: .noop,
      //            storeKit: .live(),
      //            userDefaults: update(.live()) {
      //              $0.boolForKey = { _ in false }
      //            },
      //            userNotifications: .noop
      //          )
      //        )
      //      )

      GameOverView(
        store: .init(
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
              metadata: .init()
            )
          ),
          reducer: gameOverReducer,
          environment: .preview
        )
      )
    }
  }
}
