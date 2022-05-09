import ApiClient
import ComposableArchitecture
import CubePreview
import LeaderboardFeature
import Overture
import SharedModels
import Styleguide
import SwiftUI

public struct DailyChallengeResultsState: Equatable {
  public var history: DailyChallengeHistoryResponse?
  public var leaderboardResults: LeaderboardResultsState<DailyChallenge.GameNumber?>

  public init(
    history: DailyChallengeHistoryResponse? = nil,
    leaderboardResults: LeaderboardResultsState<DailyChallenge.GameNumber?> = .init(timeScope: nil)
  ) {
    self.history = history
    self.leaderboardResults = leaderboardResults
  }
}

public enum DailyChallengeResultsAction: Equatable {
  case leaderboardResults(LeaderboardResultsAction<DailyChallenge.GameNumber?>)
  case loadHistory
  case fetchHistoryResponse(TaskResult<DailyChallengeHistoryResponse>)
}

public struct DailyChallengeResultsEnvironment {
  public var apiClient: ApiClient
  public var mainQueue: AnySchedulerOf<DispatchQueue>

  public init(
    apiClient: ApiClient,
    mainQueue: AnySchedulerOf<DispatchQueue>
  ) {
    self.apiClient = apiClient
    self.mainQueue = mainQueue
  }
}

#if DEBUG
  extension DailyChallengeResultsEnvironment {
    public static let failing = Self(
      apiClient: .failing,
      mainQueue: .failing("mainQueue")
    )
  }
#endif

public let dailyChallengeResultsReducer = Reducer<
  DailyChallengeResultsState, DailyChallengeResultsAction, DailyChallengeResultsEnvironment
>.combine(

  Reducer.leaderboardResultsReducer()
    .pullback(
      state: \DailyChallengeResultsState.leaderboardResults,
      action: /DailyChallengeResultsAction.leaderboardResults,
      environment: {
        .init(
          loadResults: $0.apiClient.loadDailyChallengeResults(gameMode:timeScope:),
          mainQueue: $0.mainQueue
        )
      }
    ),

  .init { state, action, environment in
    switch action {
    case let .fetchHistoryResponse(.success(response)):
      state.history = response
      return .none

    case .fetchHistoryResponse(.failure):
      state.history = .init(results: [])
      return .none

    case .leaderboardResults(.gameModeButtonTapped):
      if let indices = state.history?.results.indices {
        for index in indices {
          state.history?.results[index].rank = nil
        }
      }
      return .none

    case .leaderboardResults(.tappedTimeScopeLabel):
      guard
        state.leaderboardResults.isTimeScopeMenuVisible
      else { return .none }
      return .init(value: .loadHistory)

    case .leaderboardResults:
      return .none

    case .loadHistory:
      if state.history?.results.isEmpty == .some(true) {
        state.history = nil
      }

      struct CancelId {}
      return .task { @MainActor [gameMode = state.leaderboardResults.gameMode] in
        await .fetchHistoryResponse(
          TaskResult {
            try await environment.apiClient.apiRequest(
              route: .dailyChallenge(
                .results(
                  .history(
                    gameMode: gameMode,
                    language: .en
                  )
                )
              ),
              as: DailyChallengeHistoryResponse.self
            )
          }
        )
      }
      .cancellable(id: CancelId.self, cancelInFlight: true)
    }
  }
)

public struct DailyChallengeResultsView: View {
  @Environment(\.colorScheme) var colorScheme
  let store: Store<DailyChallengeResultsState, DailyChallengeResultsAction>
  @ObservedObject var viewStore: ViewStore<DailyChallengeResultsState, DailyChallengeResultsAction>

  public init(store: Store<DailyChallengeResultsState, DailyChallengeResultsAction>) {
    self.store = store
    self.viewStore = ViewStore(self.store)
  }

  public var body: some View {
    LeaderboardResultsView(
      store: self.store.scope(
        state: \.leaderboardResults,
        action: DailyChallengeResultsAction.leaderboardResults
      ),
      title: Text("Daily Challenge"),
      subtitle: (self.viewStore.leaderboardResults.resultEnvelope?.outOf)
        .flatMap { $0 == 0 ? nil : Text("\($0) players") },
      isFilterable: true,
      color: .dailyChallenge,
      timeScopeLabel: Text(self.timeScopeLabelText),
      timeScopeMenu: VStack(alignment: .trailing, spacing: .grid(2)) {
        CalendarView(store: self.store)
      }
    )
    .padding(.top, .grid(4))
    .adaptivePadding(.bottom)
    .screenEdgePadding(.horizontal)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .navigationStyle(
      backgroundColor: .adaptiveWhite,
      foregroundColor: self.colorScheme == .dark ? .dailyChallenge : .isowordsBlack,
      title: Text("Leaderboard")
    )
  }

  var timeScopeLabelText: LocalizedStringKey {
    guard
      let history = self.viewStore.history,
      let timeScope = self.viewStore.leaderboardResults.timeScope
    else { return "Today (so far)" }

    guard
      let date = history.results
        .first(where: { $0.gameNumber == timeScope })?
        .createdAt
    else { return "-" }

    var calendar = Calendar(identifier: .iso8601)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    return calendar.isDateInToday(date)
      ? "Today (so far)"
      : calendar.isDateInYesterday(date)
        ? "Yesterday"
        : "\(date, formatter: timeScopeFormatter)"
  }
}

extension ApiClient {
  func loadDailyChallengeResults(
    gameMode: GameMode,
    timeScope gameNumber: DailyChallenge.GameNumber?
  ) async throws -> ResultEnvelope {
    .init(
      try await self.apiRequest(
        route: .dailyChallenge(
          .results(
            .fetch(
              gameMode: gameMode,
              gameNumber: gameNumber,
              language: .en
            )
          )
        ),
        as: FetchDailyChallengeResultsResponse.self
      )
    )
  }
}

extension ResultEnvelope {
  public init(_ response: FetchDailyChallengeResultsResponse) {
    self.init(
      outOf: response.results.first?.outOf ?? 0,
      results: response.results.map { entry in
        .init(
          denseRank: entry.rank,
          id: entry.playerId.rawValue,
          isYourScore: entry.isYourScore,
          rank: entry.rank,
          score: entry.score,
          title: entry.playerDisplayName ?? "Someone"
        )
      }
    )
  }
}

private let timeScopeFormatter: DateFormatter = {
  let formatter = DateFormatter()
  formatter.dateStyle = .medium
  return formatter
}()
