import ActiveGamesFeature
import ClientModels
import ComposableArchitecture
import CubeCore
import HomeFeature
import Overture
import PuzzleGen
import SharedModels
import SwiftUI
import SwiftUIHelpers

var homeAppStoreView: AnyView {
  let environment = update(HomeEnvironment.noop) {
    $0.mainRunLoop = RunLoop.test.eraseToAnyScheduler()
  }
  let view = HomeView(
    store: Store(
      initialState: HomeState(
        dailyChallenges: [
          FetchTodaysDailyChallengeResponse(
            dailyChallenge: FetchTodaysDailyChallengeResponse.DailyChallenge(
              endsAt: environment.mainRunLoop.now.advanced(by: .seconds(60 * 60 * 2.5)).date,
              gameMode: .timed,
              id: .init(rawValue: .dailyChallengeId),
              language: .en
            ),
            yourResult: DailyChallengeResult(
              outOf: 1243,
              rank: nil,
              score: nil,
              started: true
            )
          ),
          FetchTodaysDailyChallengeResponse(
            dailyChallenge: FetchTodaysDailyChallengeResponse.DailyChallenge(
              endsAt: environment.mainRunLoop.now.advanced(by: .seconds(60 * 60 * 2.5)).date,
              gameMode: .unlimited,
              id: .init(rawValue: .dailyChallengeId),
              language: .en
            ),
            yourResult: DailyChallengeResult(
              outOf: 1242,
              rank: nil,
              score: nil,
              started: true
            )
          ),
        ],
        hasPastTurnBasedGames: true,
        nagBanner: nil,
        route: nil,
        savedGames: SavedGamesState(
          dailyChallengeUnlimited: InProgressGame(
            cubes: .mock,
            gameContext: .dailyChallenge(.init(rawValue: .dailyChallengeId)),
            gameMode: .unlimited,
            gameStartTime: environment.mainRunLoop.now.date,
            language: .en,
            moves: Moves(),
            secondsPlayed: 0
          ),
          unlimited: nil
        ),
        settings: .init(),
        turnBasedMatches: [
          ActiveTurnBasedMatch(
            id: "deadbeef",
            isYourTurn: true,
            lastPlayedAt: environment.mainRunLoop.now.advanced(by: -60 * 60 * 4).date,
            now: environment.mainRunLoop.now.date,
            playedWord: PlayedWord(
              isYourWord: false,
              reactions: [0: .angel],
              score: score("LIZARDS"),
              word: "LIZARDS"
            ),
            status: .open,
            theirIndex: 0,
            theirName: "millie"
          )
        ],
        weekInReview: FetchWeekInReviewResponse(
          ranks: [
            .init(gameMode: .timed, outOf: 10241, rank: 2612),
            .init(gameMode: .unlimited, outOf: 8713, rank: 1637),
          ],
          word: FetchWeekInReviewResponse.Word(
            letters: "QUEENLY",
            score: score("QUEENLY")
          )
        )
      ),
      reducer: .empty,
      environment: ()
    )
  )
  .environment(\.date) { environment.mainRunLoop.now.advanced(by: -60 * 60 * 2).date }
  return AnyView(view)
}
