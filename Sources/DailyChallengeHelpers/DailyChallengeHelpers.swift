import ApiClient
import ClientModels
import Combine
import ComposableArchitecture
import Foundation
import SharedModels

public enum DailyChallengeError: Error, Equatable {
  case alreadyPlayed(endsAt: Date)
  case couldNotFetch(nextStartsAt: Date)
}

public func startDailyChallenge(
  _ challenge: FetchTodaysDailyChallengeResponse
) async throws -> InProgressGame {
  @Dependency(\.apiClient) var apiClient
  @Dependency(\.date.now) var now
  @Shared(.savedGames) var savedGames = SavedGamesState()

  guard challenge.yourResult.rank == nil
  else {
    throw DailyChallengeError.alreadyPlayed(endsAt: challenge.dailyChallenge.endsAt)
  }
  guard
    challenge.dailyChallenge.gameMode == .unlimited,
    let game = savedGames.dailyChallengeUnlimited
  else {
    do {
      return try await InProgressGame(
        response: apiClient.apiRequest(
          route: .dailyChallenge(
            .start(
              gameMode: challenge.dailyChallenge.gameMode,
              language: challenge.dailyChallenge.language
            )
          ),
          as: StartDailyChallengeResponse.self
        ),
        date: now
      )
    } catch {
      throw DailyChallengeError.couldNotFetch(nextStartsAt: challenge.dailyChallenge.endsAt)
    }
  }
  return game
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
