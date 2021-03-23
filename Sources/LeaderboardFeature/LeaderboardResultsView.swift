import ComposableArchitecture
import SharedModels
import SwiftUI

public struct LeaderboardResultsState<TimeScope> {
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

extension LeaderboardResultsState: Equatable where TimeScope: Equatable {}

public enum LeaderboardResultsAction<TimeScope> {
  case dismissTimeScopeMenu
  case gameModeButtonTapped(GameMode)
  case resultsResponse(Result<ResultEnvelope, ApiError>)
  case onAppear
  case tappedRow(id: UUID)
  case tappedTimeScopeLabel
  case timeScopeChanged(TimeScope)
}

extension LeaderboardResultsAction: Equatable where TimeScope: Equatable {}

public struct LeaderboardResultsEnvironment<TimeScope> {
  public let loadResults: (GameMode, TimeScope) -> Effect<ResultEnvelope, ApiError>
  public let mainQueue: AnySchedulerOf<DispatchQueue>

  public init(
    loadResults: @escaping (GameMode, TimeScope) -> Effect<ResultEnvelope, ApiError>,
    mainQueue: AnySchedulerOf<DispatchQueue>
  ) {
    self.loadResults = loadResults
    self.mainQueue = mainQueue
  }
}

extension Reducer {
  public static func leaderboardResultsReducer<TimeScope>() -> Self
  where
    State == LeaderboardResultsState<TimeScope>,
    Action == LeaderboardResultsAction<TimeScope>,
    Environment == LeaderboardResultsEnvironment<TimeScope>
  {

    Self { state, action, environment in
      switch action {
      case .dismissTimeScopeMenu:
        state.isTimeScopeMenuVisible = false
        return .none

      case let .gameModeButtonTapped(gameMode):
        state.gameMode = gameMode
        state.isLoading = true
        return environment.loadResults(state.gameMode, state.timeScope)
          .receive(on: environment.mainQueue.animation())
          .catchToEffect()
          .map(LeaderboardResultsAction.resultsResponse)

      case .onAppear:
        state.isLoading = true
        state.isTimeScopeMenuVisible = false
        state.resultEnvelope = .placeholder

        return environment.loadResults(state.gameMode, state.timeScope)
          .receive(on: environment.mainQueue.animation())
          .catchToEffect()
          .map(LeaderboardResultsAction.resultsResponse)

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

      case let .timeScopeChanged(timeScope):
        state.isLoading = true
        state.isTimeScopeMenuVisible = false
        state.timeScope = timeScope

        return environment.loadResults(state.gameMode, state.timeScope)
          .receive(on: environment.mainQueue.animation())
          .catchToEffect()
          .map(LeaderboardResultsAction.resultsResponse)
      }
    }
  }
}

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

  public typealias State = LeaderboardResultsState<TimeScope>
  public typealias Action = LeaderboardResultsAction<TimeScope>

  let store: Store<State, Action>
  @ObservedObject var viewStore: ViewStore<State, Action>

  public init(
    store: Store<State, Action>,
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
    self.viewStore = ViewStore(self.store)
    self.timeScopeLabel = timeScopeLabel
    self.timeScopeMenu = timeScopeMenu
    self.title = title
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack {
        (self.title ?? Text("Loading"))
          .animation(nil)
          .adaptiveFont(.matterMedium, size: 16)
          .frame(maxWidth: .infinity, alignment: .leading)
          .foregroundColor(self.colorScheme == .dark ? self.color : .isowordsBlack)
          .redacted(reason: self.title == nil ? .placeholder : [])

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
            .animation(nil)
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
            .animation(nil)

            if let result = self.viewStore.resultEnvelope?.nonContiguousResult {
              Image(systemName: "ellipsis")
                .opacity(0.4)
                .adaptivePadding([.top, .bottom], .grid(5))
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
        .animation(nil)
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
    .onAppear { self.viewStore.send(.onAppear) }
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
      Preview {
        LeaderboardResultsView(
          store: .init(
            initialState: LeaderboardResultsState(
              gameMode: .timed,
              isLoading: false,
              resultEnvelope: nil,
              timeScope: .lastWeek
            ),
            reducer: .leaderboardResultsReducer(),
            environment: LeaderboardResultsEnvironment(
              loadResults: { _, _ in
                Effect(
                  value: .init(
                    outOf: 1000,
                    results: ([1, 2, 3, 4, 5, 7]).map { index in
                      ResultEnvelope.Result(
                        denseRank: index,
                        id: UUID(),
                        isYourScore: index == 3,
                        rank: index,
                        score: 6000 - index * 800,
                        subtitle: "mbrandonw",
                        title: "Longword\(index)"
                      )
                    }
                  )
                )
              },
              mainQueue: DispatchQueue.main.eraseToAnyScheduler()
            )
          ),
          title: Text("362,998 words"),
          subtitle: nil,
          isFilterable: true,
          color: .isowordsRed,
          timeScopeLabel: Text("Today"),
          timeScopeMenu: EmptyView()
        )
        .padding()

        LeaderboardResultsView(
          store: .init(
            initialState: LeaderboardResultsState(
              gameMode: .timed,
              isLoading: false,
              resultEnvelope: nil,
              timeScope: .lastWeek
            ),
            reducer: .leaderboardResultsReducer(),
            environment: LeaderboardResultsEnvironment(
              loadResults: { _, _ in
                Effect(
                  value: .init(
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
                )
                .delay(for: 1, scheduler: DispatchQueue.main.animation())
                .eraseToEffect()
              },
              mainQueue: DispatchQueue.main.eraseToAnyScheduler()
            )
          ),
          title: Text("Daily challenge"),
          subtitle: Text("1,234 games"),
          isFilterable: true,
          color: .isowordsYellow,
          timeScopeLabel: Text("Today"),
          timeScopeMenu: EmptyView()
        )
        .padding()

        LeaderboardResultsView(
          store: .init(
            initialState: LeaderboardResultsState(
              gameMode: .timed,
              isLoading: false,
              resultEnvelope: nil,
              timeScope: .lastWeek
            ),
            reducer: .leaderboardResultsReducer(),
            environment: LeaderboardResultsEnvironment(
              loadResults: { _, _ in .init(error: .init(error: NSError(domain: "", code: 1))) },
              mainQueue: DispatchQueue.main.eraseToAnyScheduler()
            )
          ),
          title: Text("Solo"),
          subtitle: Text("1,234 games"),
          isFilterable: true,
          color: .isowordsOrange,
          timeScopeLabel: Text("Today"),
          timeScopeMenu: EmptyView()
        )
        .padding()
      }
    }
  }
#endif
