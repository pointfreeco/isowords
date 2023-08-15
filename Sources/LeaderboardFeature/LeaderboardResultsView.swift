import ComposableArchitecture
import SharedModels
import SwiftUI

public struct LeaderboardResults<TimeScope>: ReducerProtocol {
  public struct State {
    public var gameMode: GameMode
    public var isLoading: Bool
    public var isTimeScopeMenuVisible: Bool
    public var resultEnvelope: ResultEnvelope?
    public var timeScope: TimeScope

    public init(
      gameMode: GameMode = .timed,
      isLoading: Bool = false,
      isTimeScopeMenuVisible: Bool = false,
      resultEnvelope: ResultEnvelope? = nil,
      timeScope: TimeScope
    ) {
      self.gameMode = gameMode
      self.isLoading = isLoading
      self.isTimeScopeMenuVisible = isTimeScopeMenuVisible
      self.resultEnvelope = resultEnvelope
      self.timeScope = timeScope
    }

    var nonDisplayedResultsCount: Int {
      (self.resultEnvelope?.outOf ?? 0)
        - (self.resultEnvelope?.nonContiguousResult?.rank ?? self.resultEnvelope?.results.count ?? 0)
    }
  }

  public enum Action {
    case dismissTimeScopeMenu
    case gameModeButtonTapped(GameMode)
    case resultsResponse(TaskResult<ResultEnvelope>)
    case tappedRow(id: UUID)
    case tappedTimeScopeLabel
    case task
    case timeScopeChanged(TimeScope)
  }

  public let loadResults: @Sendable (GameMode, TimeScope) async throws -> ResultEnvelope

  public init(
    loadResults: @escaping @Sendable (GameMode, TimeScope) async throws -> ResultEnvelope
  ) {
    self.loadResults = loadResults
  }

  public func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
    switch action {
    case .dismissTimeScopeMenu:
      state.isTimeScopeMenuVisible = false
      return .none

    case let .gameModeButtonTapped(gameMode):
      state.gameMode = gameMode
      state.isLoading = true
      return .task { [timeScope = state.timeScope] in
        await .resultsResponse(
          TaskResult { try await self.loadResults(gameMode, timeScope) }
        )
      }
      .animation()

    case .resultsResponse(.failure):
      state.isLoading = false
      state.resultEnvelope = nil
      return .none

    case let .resultsResponse(.success(envelope)):
      state.isLoading = false
      state.resultEnvelope = envelope
      return .none

    case .tappedRow:
      return .none

    case .tappedTimeScopeLabel:
      state.isTimeScopeMenuVisible.toggle()
      return .none

    case .task:
      state.isLoading = true
      state.isTimeScopeMenuVisible = false
      state.resultEnvelope = .placeholder

      return .task { [gameMode = state.gameMode, timeScope = state.timeScope] in
        await .resultsResponse(
          TaskResult { try await self.loadResults(gameMode, timeScope) }
        )
      }
      .animation()

    case let .timeScopeChanged(timeScope):
      state.isLoading = true
      state.isTimeScopeMenuVisible = false
      state.timeScope = timeScope

      return .task { [gameMode = state.gameMode] in
        await .resultsResponse(
          TaskResult { try await self.loadResults(gameMode, timeScope) }
        )
      }
      .animation()
    }
  }
}

extension LeaderboardResults.State: Equatable where TimeScope: Equatable {}
extension LeaderboardResults.Action: Equatable where TimeScope: Equatable {}

public struct LeaderboardResultsView<TimeScope, TimeScopeMenu>: View
where
  TimeScope: Equatable,
  TimeScopeMenu: View
{
  let color: Color
  @Environment(\.colorScheme) var colorScheme
  let isFilterable: Bool
  let subtitle: Text?
  let timeScopeLabel: Text?
  let timeScopeMenu: TimeScopeMenu?
  let title: Text?

  let store: StoreOf<LeaderboardResults<TimeScope>>
  @ObservedObject var viewStore: ViewStoreOf<LeaderboardResults<TimeScope>>

  public init(
    store: StoreOf<LeaderboardResults<TimeScope>>,
    title: Text?,
    subtitle: Text?,
    isFilterable: Bool,
    color: Color,
    timeScopeLabel: Text,
    timeScopeMenu: TimeScopeMenu
  ) {
    self.color = color
    self.isFilterable = isFilterable
    self.subtitle = subtitle
    self.store = store
    self.viewStore = ViewStore(self.store, observe: { $0 })
    self.timeScopeLabel = timeScopeLabel
    self.timeScopeMenu = timeScopeMenu
    self.title = title
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack {
        self.title
          .animation(nil)
          .adaptiveFont(.matterMedium, size: 16)
          .frame(maxWidth: .infinity, alignment: .leading)
          .foregroundColor(self.colorScheme == .dark ? self.color : .isowordsBlack)
          .redacted(reason: self.viewStore.isLoading ? .placeholder : [])

        Spacer()

        Button(action: { self.viewStore.send(.tappedTimeScopeLabel, animation: .default) }) {
          HStack {
            self.timeScopeLabel
              .adaptiveFont(.matterMedium, size: 10)
            Image(systemName: "chevron.down")
              .font(.system(size: 10))
              .rotationEffect(
                .degrees(self.viewStore.isTimeScopeMenuVisible ? -180 : 0)
              )
          }
          .padding([.top, .bottom], 8)
          .padding([.leading, .trailing], 16)
          .background(self.color.opacity(self.colorScheme == .dark ? 0.1 : 0.3))
          .foregroundColor(self.colorScheme == .dark ? self.color : .isowordsBlack)
          .continuousCornerRadius(.grid(5))
        }
      }

      VStack(alignment: .leading, spacing: 0) {
        if self.isFilterable {
          HStack(spacing: .grid(4)) {
            ForEach(GameMode.allCases) { gameMode in
              Button(action: { self.viewStore.send(.gameModeButtonTapped(gameMode)) }) {
                Text(gameMode.title)
                  .adaptiveFont(.matterMedium, size: 12)
                  .opacity(self.viewStore.gameMode == gameMode ? 1 : 0.4)
              }
              .buttonStyle(PlainButtonStyle())
            }
          }
          .padding([.leading, .trailing, .bottom], .grid(5))
          .padding(self.isFilterable ? [.top] : [], .grid(5))

          Divider()
        }

        ScrollView {
          if !self.isFilterable {
            Spacer().frame(height: .grid(6))
          }

          self.subtitle
            .adaptiveFont(.matterMedium, size: 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.init(top: .grid(4), leading: .grid(5), bottom: .grid(3), trailing: .grid(5)))

          Group {
            ForEach(
              self.viewStore.resultEnvelope?.contiguousResults ?? [], id: \.id
            ) { result in
              Button(action: { self.viewStore.send(.tappedRow(id: result.id)) }) {
                ResultRow(color: self.color, result: result)
              }
            }

            if let result = self.viewStore.resultEnvelope?.nonContiguousResult {
              Image(systemName: "ellipsis")
                .opacity(0.4)
                .adaptivePadding(.vertical, .grid(5))
                .adaptiveFont(.matterMedium, size: 16)

              Button(action: { self.viewStore.send(.tappedRow(id: result.id)) }) {
                ResultRow(color: self.color, result: result)
              }
            }

            if self.viewStore.nonDisplayedResultsCount > 0 {
              VStack(spacing: .grid(5)) {
                Image(systemName: "ellipsis")
                  .opacity(0.4)
                Text("and \(self.viewStore.nonDisplayedResultsCount) more!")
              }
              .adaptivePadding([.top], .grid(5))
              .adaptiveFont(.matterMedium, size: 16)
            }
          }

          Spacer().frame(height: .grid(5))
        }
        .disabled(self.viewStore.isLoading)
        .redacted(reason: self.viewStore.isLoading ? .placeholder : [])
      }
      .background(self.color)
      .foregroundColor(.isowordsBlack)
      .overlay(
        self.viewStore.isLoading
          ? ZStack {
            Color.black
              .opacity(0.4)
            ProgressView()
              .progressViewStyle(CircularProgressViewStyle(tint: .white))
          }
          : nil
      )
      .overlay(
        self.viewStore.isTimeScopeMenuVisible
          ? Color.black.opacity(0.4)
            .onTapGesture {
              self.viewStore.send(.dismissTimeScopeMenu, animation: .default)
            }
          : nil
      )
      .continuousCornerRadius(.grid(3))
    }
    .overlay(
      self.viewStore.isTimeScopeMenuVisible
        ? VStack {
          self.timeScopeMenu
            .adaptiveFont(.matterMedium, size: 12)
        }
        .padding([.top, .bottom], .grid(4))
        .padding([.leading, .trailing], .grid(5))
        .background(self.color.opacity(self.colorScheme == .dark ? 0.1 : 0.3))
        .background(Color.adaptiveWhite)
        .foregroundColor(self.colorScheme == .dark ? self.color : .isowordsBlack)
        .continuousCornerRadius(.grid(5))
        .padding(.leading, .grid(8))
        .offset(y: .grid(11))
        .transition(
          AnyTransition.scale(scale: 0, anchor: .topTrailing)
            .combined(with: .opacity)
            .animation(.spring())
        )
        : nil,
      alignment: .topTrailing

    )
    .task { await self.viewStore.send(.task).finish() }
  }
}

struct ResultRow: View {
  @Environment(\.adaptiveSize) var adaptiveSize
  @Environment(\.colorScheme) var colorScheme
  let color: Color
  let result: ResultEnvelope.Result

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: .grid(2)) {
      self.result.rank
        .formatted(font: .custom(.matterMedium, size: self.adaptiveSize.pad(12)))
        .opacity(0.5)
        .frame(width: 40, alignment: .center)
      VStack(alignment: .leading) {
        Text(self.result.title)
          .adaptiveFont(.matterMedium, size: 14)
          .lineLimit(1)

        if let subtitle = self.result.subtitle {
          Text(subtitle)
            .adaptiveFont(.matterMedium, size: 12)
            .lineLimit(1)
            .opacity(0.5)
        }
      }
      Spacer()
      self.result.score
        .formatted(font: .custom(.matterSemiBold, size: self.adaptiveSize.pad(12)))
    }
    .foregroundColor(self.result.isYourScore ? self.color : .isowordsBlack)
    .padding([.vertical], self.result.isYourScore ? .grid(1) : 0)
    .padding([.leading, .trailing], .grid(2))
    .background(
      self.result.isYourScore
        ? RoundedRectangle(cornerRadius: .grid(2), style: .continuous)
          .fill(Color.isowordsBlack)
        : nil
    )
    .padding([.leading, .trailing])
    .padding([.top, .bottom], .grid(1) / 2)
  }
}

private let decimalFormatter: NumberFormatter = {
  let formatter = NumberFormatter()
  formatter.numberStyle = .decimal
  return formatter
}()

extension Int {
  func formatted(font: Font, locale: Locale = .autoupdatingCurrent) -> Text {
    guard let formatted = decimalFormatter.string(from: self as NSNumber)
    else { return Text("") }

    let groupings =
      formatted
      .components(separatedBy: decimalFormatter.groupingSeparator)
      .map { Text($0).font(font.monospacedDigit()) }

    guard let first = groupings.first
    else { return Text("") }

    return groupings.dropFirst().reduce(first) {
      $0 + Text(decimalFormatter.groupingSeparator).font(font) + $1
    }
  }
}

extension GameMode {
  fileprivate var title: LocalizedStringKey {
    switch self {
    case .timed:
      return "Timed"
    case .unlimited:
      return "Unlimited"
    }
  }
}

extension ResultEnvelope {
  static let placeholder = Self(
    outOf: 0,
    results: (1...10).map { idx in
      ResultEnvelope.Result(
        denseRank: idx,
        id: .deadbeef,
        rank: idx,
        score: 1_000,
        subtitle: "Subtitle",
        title: "Title"
      )
    }
  )
}

#if DEBUG
  import SwiftUIHelpers

  struct LeaderboardResultsView_Previews: PreviewProvider {
    static var previews: some View {
      LeaderboardResultsView(
        store: Store(
          initialState: LeaderboardResults.State(
            gameMode: GameMode.timed,
            timeScope: TimeScope.lastWeek
          )
        ) {
          LeaderboardResults<TimeScope>(
            loadResults: { _, _ in
              ResultEnvelope(
                outOf: 1000,
                results: ([1, 2, 3, 4, 5, 6, 7, 7, 15]).map { index in
                  ResultEnvelope.Result(
                    denseRank: index,
                    id: UUID(),
                    isYourScore: index == 15,
                    rank: index,
                    score: 6000 - index * 300,
                    subtitle: "mbrandonw",
                    title: "Longword\(index)"
                  )
                }
              )
            }
          )
        },
        title: Text("362,998 words"),
        subtitle: nil,
        isFilterable: false,
        color: .isowordsRed,
        timeScopeLabel: Text("Today"),
        timeScopeMenu: EmptyView()
      )
      .padding()
      .previewDisplayName("Words")

      LeaderboardResultsView(
        store: Store(
          initialState: LeaderboardResults.State(
            gameMode: GameMode.timed,
            timeScope: TimeScope.lastWeek
          )
        ) {
          LeaderboardResults<TimeScope>(
            loadResults: { _, _ in
              ResultEnvelope(
                outOf: 1000,
                results: (1...5).map { index in
                  ResultEnvelope.Result(
                    denseRank: index,
                    id: UUID(),
                    isYourScore: index == 3,
                    rank: index,
                    score: 6000 - index * 800,
                    title: "Player \(index)"
                  )
                }
              )
            }
          )
        },
        title: Text("Daily challenge"),
        subtitle: Text("1,234 games"),
        isFilterable: true,
        color: .isowordsYellow,
        timeScopeLabel: Text("Today"),
        timeScopeMenu: EmptyView()
      )
      .padding()
      .previewDisplayName("Daily challenge")

      LeaderboardResultsView(
        store: Store(
          initialState: LeaderboardResults.State(
            gameMode: GameMode.timed,
            isLoading: false,
            resultEnvelope: nil,
            timeScope: TimeScope.lastWeek
          )
        ) {
          LeaderboardResults<TimeScope>(
            loadResults: { _, _ in
              struct Failure: Error {}
              throw Failure()
            }
          )
        },
        title: Text("Solo"),
        subtitle: Text("1,234 games"),
        isFilterable: true,
        color: .isowordsOrange,
        timeScopeLabel: Text("Today"),
        timeScopeMenu: EmptyView()
      )
      .padding()
      .previewDisplayName("Failed state")
    }
  }
#endif
