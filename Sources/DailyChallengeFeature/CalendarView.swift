import ComposableArchitecture
import Overture
import SharedModels
import SwiftUI

struct CalendarView: View {
  struct ViewState: Equatable {
    let currentChallenge: DailyChallenge.GameNumber?
    let isLoading: Bool
    let months: [Month]

    init(state: DailyChallengeResults.State) {
      self.currentChallenge =
        state.leaderboardResults.timeScope
        ?? state.history?.results.first?.gameNumber
      if let history = state.history {
        self.isLoading = false
        self.months =
          Dictionary
          .init(
            grouping: history.results,
            by: {
              Calendar.autoupdatingCurrent.date(
                from: Calendar.autoupdatingCurrent.dateComponents([.month], from: $0.createdAt)
              )
            }
          )
          .map(Month.init)
          .sorted(by: >)
      } else {
        self.isLoading = true
        self.months = [
          .init(
            date: nil,
            results: (1...30).map {
              .init(
                createdAt: .init(), gameNumber: .init(rawValue: $0), isToday: $0 == 1, rank: nil)
            })
        ]
      }
    }

    struct Month: Comparable, Equatable {
      let date: Date?
      let results: [DailyChallengeHistoryResponse.Result]

      static func < (lhs: Self, rhs: Self) -> Bool {
        let lhsCreatedAt = lhs.results.max(by: their(\.createdAt))?.createdAt
        let rhsCreatedAt = rhs.results.max(by: their(\.createdAt))?.createdAt
        switch (lhsCreatedAt, rhsCreatedAt) {
        case let (.some(lhsCreatedAt), .some(rhsCreatedAt)):
          return lhsCreatedAt < rhsCreatedAt
        default:
          return false
        }
      }

      var name: LocalizedStringKey {
        self.date.map { "\($0, formatter: monthFormatter)" }
          ?? "Loading"
      }
    }
  }

  let store: StoreOf<DailyChallengeResults>
  @ObservedObject var viewStore: ViewStore<ViewState, DailyChallengeResults.Action>

  init(
    store: StoreOf<DailyChallengeResults>
  ) {
    self.store = store
    self.viewStore = ViewStore(store, observe: ViewState.init)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: .grid(4)) {
      ForEach(self.viewStore.months, id: \.date) { month in
        VStack(alignment: .leading) {
          Text(month.name)
            .adaptiveFont(.matterMedium, size: 14)
            .opacity(0.4)
          LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: .grid(1)), count: 7),
            spacing: .grid(1)
          ) {
            ForEach(month.results, id: \.gameNumber) { result in
              Button(
                action: {
                  self.viewStore.send(.leaderboardResults(.timeScopeChanged(result.gameNumber)))
                }
              ) {
                VStack {
                  Text("\(dayFormatter.string(from: result.createdAt))")
                    .adaptiveFont(.matterMedium, size: 14)
                  Text(result.rank.map { "\($0 as NSNumber, formatter: rankFormatter)" } ?? "-")
                    .adaptiveFont(.matterMedium, size: 8)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .opacity(0.4)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.vertical, .grid(1) / 2)
                .background(
                  self.viewStore.currentChallenge == result.gameNumber
                    ? RoundedRectangle(cornerRadius: .grid(2), style: .continuous)
                      .fill(Color.adaptiveWhite)
                    : nil
                )
              }
            }
          }
          .padding(.horizontal, -.grid(3))
          .padding(.bottom, -.grid(1))
        }
      }

      if self.viewStore.months.isEmpty {
        HStack {
          Button(action: { self.viewStore.send(.loadHistory) }) {
            Image(systemName: "arrow.clockwise")
          }

          Text("Couldn’t fetch history")
            .adaptiveFont(.matterMedium, size: 14)
        }
      }
    }
    .redacted(reason: self.viewStore.isLoading ? .placeholder : [])
    .disabled(self.viewStore.isLoading)
    .overlay(
      self.viewStore.isLoading
        ? ProgressView()
          .progressViewStyle(CircularProgressViewStyle(tint: .black))
        : nil
    )
  }
}

private let dayFormatter: DateFormatter = {
  let formatter = DateFormatter()
  formatter.dateFormat = "d"
  return formatter
}()

private let monthFormatter: DateFormatter = {
  let formatter = DateFormatter()
  formatter.dateFormat = "MMMM"
  return formatter
}()

private let rankFormatter: NumberFormatter = {
  let formatter = NumberFormatter()
  formatter.numberStyle = .ordinal
  return formatter
}()
