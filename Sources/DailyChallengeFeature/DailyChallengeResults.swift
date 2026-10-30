import ApiClient
import ComposableArchitecture
import Dependencies
import LeaderboardFeature
import SharedModels
import SwiftUI

@Feature
public struct DailyChallengeResults {
  public struct State {
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

  public enum Action {
    case leaderboardResults(LeaderboardResults<DailyChallenge.GameNumber?>.Action)
    case reloadHistoryButtonTapped
  }

  @Dependency(\.apiClient) var apiClient
  @StoreTaskID var historyRequest

  public init() {}

  public var body: some Feature {
    Scope(\.leaderboardResults) {
      LeaderboardResults(loadResults: apiClient.loadDailyChallengeResults)
    }

    Update { state, action in
      switch action {
      case .leaderboardResults(.gameModeButtonTapped):
        if let indices = state.history?.results.indices {
          for index in indices {
            state.history?.results[index].rank = nil
          }
        }

      case .leaderboardResults:
        break

      case .reloadHistoryButtonTapped:
        loadHistory(&state)
      }
    }
    .onChange(of: store.leaderboardResults.isTimeScopeMenuVisible) { _, isVisible, state in
      guard isVisible else { return }
      loadHistory(&state)
    }
  }

  private func loadHistory(_ state: inout State) {
    if state.history?.results.isEmpty == .some(true) {
      state.history = nil
    }

    store.addTask(id: historyRequest) { [gameMode = state.leaderboardResults.gameMode] in
      let history: DailyChallengeHistoryResponse
      do {
        history = try await apiClient.apiRequest(
          route: .dailyChallenge(.results(.history(gameMode: gameMode, language: .en))),
          as: DailyChallengeHistoryResponse.self
        )
      } catch is CancellationError {
        return
      } catch {
        history = .init(results: [])
      }
      try store.modify { $0.history = history }
    }
  }
}

public struct DailyChallengeResultsView: View {
  @Environment(\.colorScheme) var colorScheme
  let store: StoreOf<DailyChallengeResults>

  public init(store: StoreOf<DailyChallengeResults>) {
    self.store = store
  }

  public var body: some View {
    LeaderboardResultsView(
      store: store.scope(\.leaderboardResults),
      title: Text("Daily Challenge"),
      subtitle: (store.leaderboardResults.resultEnvelope?.outOf)
        .flatMap { $0 == 0 ? nil : Text("\($0) players") },
      isFilterable: true,
      color: .dailyChallenge,
      timeScopeLabel: Text(self.timeScopeLabelText),
      timeScopeMenu: VStack(alignment: .trailing, spacing: .grid(2)) {
        CalendarView(store: store)
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
      let history = store.history,
      let timeScope = store.leaderboardResults.timeScope
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
