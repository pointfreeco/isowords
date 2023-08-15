import ApiClient
import ComposableArchitecture
import LeaderboardFeature
import SharedModels
import SwiftUI

public struct DailyChallengeResults: Reducer {
  public struct State: Equatable {
    public var history: DailyChallengeHistoryResponse?
    public var leaderboardResults: LeaderboardResults<DailyChallenge.GameNumber?>.State

    public init(
      history: DailyChallengeHistoryResponse? = nil,
      leaderboardResults: LeaderboardResults<DailyChallenge.GameNumber?>.State =
        .init(timeScope: nil)
    ) {
      self.history = history
      self.leaderboardResults = leaderboardResults
    }
  }

  public enum Action: Equatable {
    case leaderboardResults(LeaderboardResults<DailyChallenge.GameNumber?>.Action)
    case loadHistory
    case fetchHistoryResponse(TaskResult<DailyChallengeHistoryResponse>)
  }

  @Dependency(\.apiClient) var apiClient

  public init() {}

  public var body: some Reducer<State, Action> {
    Scope(state: \.leaderboardResults, action: /Action.leaderboardResults) {
      LeaderboardResults(loadResults: self.apiClient.loadDailyChallengeResults)
    }

    Reduce { state, action in
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
        return .task { .loadHistory }

      case .leaderboardResults:
        return .none

      case .loadHistory:
        if state.history?.results.isEmpty == .some(true) {
          state.history = nil
        }

        enum CancelID { case fetch }
        return .task { [gameMode = state.leaderboardResults.gameMode] in
          await .fetchHistoryResponse(
            TaskResult {
              try await self.apiClient.apiRequest(
                route: .dailyChallenge(.results(.history(gameMode: gameMode, language: .en))),
                as: DailyChallengeHistoryResponse.self
              )
            }
          )
        }
        .cancellable(id: CancelID.fetch, cancelInFlight: true)
      }
    }
  }
}

public struct DailyChallengeResultsView: View {
  @Environment(\.colorScheme) var colorScheme
  let store: StoreOf<DailyChallengeResults>
  @ObservedObject var viewStore: ViewStoreOf<DailyChallengeResults>

  public init(store: StoreOf<DailyChallengeResults>) {
    self.store = store
    self.viewStore = ViewStore(self.store, observe: { $0 })
  }

  public var body: some View {
    LeaderboardResultsView(
      store: self.store.scope(
        state: \.leaderboardResults,
        action: DailyChallengeResults.Action.leaderboardResults
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
  @Sendable
  func loadDailyChallengeResults(
    gameMode: GameMode,
    timeScope gameNumber: DailyChallenge.GameNumber?
  ) async throws -> ResultEnvelope {
    try await ResultEnvelope(
      self.apiRequest(
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
