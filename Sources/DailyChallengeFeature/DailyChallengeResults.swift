import ApiClient
import ComposableArchitecture
import CubePreview
import LeaderboardFeature
import Overture
import SharedModels
import Styleguide
import SwiftUI

public struct DailyChallengeResultsFeature: ReducerProtocol {
  public struct State: Equatable {
    public var history: DailyChallengeHistoryResponse?
    public var leaderboardResults: LeaderboardResultsFeature<DailyChallenge.GameNumber?>.State

    public init(
      history: DailyChallengeHistoryResponse? = nil,
      leaderboardResults: LeaderboardResultsFeature<DailyChallenge.GameNumber?>.State
      = .init(timeScope: nil)
    ) {
      self.history = history
      self.leaderboardResults = leaderboardResults
    }
  }

  public enum Action: Equatable {
    case leaderboardResults(LeaderboardResultsFeature<DailyChallenge.GameNumber?>.Action)
    case loadHistory
    case fetchHistoryResponse(Result<DailyChallengeHistoryResponse, ApiError>)
  }

  @Dependency(\.apiClient) var apiClient
  @Dependency(\.mainQueue) var mainQueue

  public var body: some ReducerProtocol<State, Action> {
    Pullback(state: \.leaderboardResults, action: /Action.leaderboardResults) {
      LeaderboardResultsFeature(
        loadResults: self.apiClient.loadDailyChallengeResults(gameMode:timeScope:)
      )
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
        return .init(value: .loadHistory)

      case .leaderboardResults:
        return .none

      case .loadHistory:
        if state.history?.results.isEmpty == .some(true) {
          state.history = nil
        }

        enum CancelId {}
        return self.apiClient.apiRequest(
          route: .dailyChallenge(
            .results(
              .history(
                gameMode: state.leaderboardResults.gameMode,
                language: .en
              )
            )
          ),
          as: DailyChallengeHistoryResponse.self
        )
        .receive(on: self.mainQueue)
        .catchToEffect(Action.fetchHistoryResponse)
        .cancellable(id: CancelId.self, cancelInFlight: true)
      }
    }
  }
}

public struct DailyChallengeResultsView: View {
  @Environment(\.colorScheme) var colorScheme
  let store: StoreOf<DailyChallengeResultsFeature>
  @ObservedObject var viewStore: ViewStoreOf<DailyChallengeResultsFeature>

  public init(store: StoreOf<DailyChallengeResultsFeature>) {
    self.store = store
    self.viewStore = ViewStore(self.store)
  }

  public var body: some View {
    LeaderboardResultsView(
      store: self.store.scope(
        state: \.leaderboardResults,
        action: DailyChallengeResultsFeature.Action.leaderboardResults
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
  ) -> Effect<ResultEnvelope, ApiError> {
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
    .map(ResultEnvelope.init)
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
