import ApiClient
import ClientModels
import Combine
import ComposableArchitecture
import FileClient
import Foundation
import SharedModels

public enum DailyChallengeError: Error, Equatable {
  case alreadyPlayed(endsAt: Date)
  case couldNotFetch(nextStartsAt: Date)
}

public func startDailyChallenge(
  _ challenge: FetchTodaysDailyChallengeResponse,
  apiClient: ApiClient,
  date: @escaping () -> Date,
  fileClient: FileClient,
  mainRunLoop: AnySchedulerOf<RunLoop>
) -> Effect<InProgressGame, DailyChallengeError> {
  guard challenge.yourResult.rank == nil else {
    return Effect(error: .alreadyPlayed(endsAt: challenge.dailyChallenge.endsAt))
  }

  return Effect.concatenate(
    challenge.dailyChallenge.gameMode == .unlimited
      ? fileClient
        .loadSavedGames()
        .tryMap { try $0.get() }
        .ignoreFailure(setFailureType: DailyChallengeError.self)
        .compactMap(\.dailyChallengeUnlimited)
        .eraseToEffect()
      : .none,
    apiClient
      .apiRequest(
        route: .dailyChallenge(
          .start(
            gameMode: challenge.dailyChallenge.gameMode,
            language: challenge.dailyChallenge.language
          )
        ),
        as: StartDailyChallengeResponse.self
      )
      .map { InProgressGame(response: $0, date: date()) }
      .mapError { err in .couldNotFetch(nextStartsAt: challenge.dailyChallenge.endsAt) }
      .eraseToEffect()
  )
  .prefix(1)
  .receive(on: mainRunLoop)
  .eraseToEffect()
}

extension InProgressGame {
  public init(response: StartDailyChallengeResponse, date: Date) {
    self.init(
      cubes: Puzzle(archivableCubes: response.dailyChallenge.puzzle),
      gameContext: .dailyChallenge(response.dailyChallenge.id),
      gameMode: response.dailyChallenge.gameMode,
      gameStartTime: date,
      language: response.dailyChallenge.language,
      moves: [],
      secondsPlayed: 0
    )
  }
}
