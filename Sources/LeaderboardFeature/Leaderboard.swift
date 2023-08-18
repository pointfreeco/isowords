import ApiClient
import ComposableArchitecture
import CubeCore
import CubePreview
import SharedModels
import SwiftUI
import UserSettingsClient

public enum LeaderboardScope: CaseIterable, Equatable {
  case games
  case vocab

  var title: LocalizedStringKey {
    switch self {
    case .games:
      return "Games"
    case .vocab:
      return "Vocab"
    }
  }

  var color: Color {
    switch self {
    case .games:
      return .isowordsOrange
    case .vocab:
      return .isowordsRed
    }
  }
}

public struct Leaderboard: Reducer {
  public struct Destination: Reducer {
    public enum State: Equatable {
      case cubePreview(CubePreview.State)
    }
    public enum Action: Equatable {
      case cubePreview(CubePreview.Action)
    }
    public var body: some ReducerOf<Self> {
      Scope(state: /State.cubePreview, action: /Action.cubePreview) {
        CubePreview()
      }
    }
  }

  public struct State: Equatable {
    @PresentationState public var destination: Destination.State?
    public var scope: LeaderboardScope = .games
    public var solo: LeaderboardResults<TimeScope>.State = .init(timeScope: .lastWeek)
    public var vocab: LeaderboardResults<TimeScope>.State = .init(timeScope: .lastWeek)

    public init(
      destination: Destination.State? = nil,
      scope: LeaderboardScope = .games,
      solo: LeaderboardResults<TimeScope>.State = .init(timeScope: .lastWeek),
      vocab: LeaderboardResults<TimeScope>.State = .init(timeScope: .lastWeek)
    ) {
      self.destination = destination
      self.scope = scope
      self.solo = solo
      self.vocab = vocab
    }
  }

  public enum Action: Equatable {
    case destination(PresentationAction<Destination.Action>)
    case fetchWordResponse(TaskResult<FetchVocabWordResponse>)
    case scopeTapped(LeaderboardScope)
    case solo(LeaderboardResults<TimeScope>.Action)
    case vocab(LeaderboardResults<TimeScope>.Action)
  }

  @Dependency(\.apiClient) var apiClient

  public init() {}

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .destination:
        return .none

      case .fetchWordResponse(.failure):
        return .none

      case let .fetchWordResponse(.success(response)):
        state.destination = .cubePreview(
          CubePreview.State(
            cubes: response.puzzle,
            moveIndex: response.moveIndex,
            moves: response.moves
          )
        )
        return .none

      case let .scopeTapped(scope):
        state.scope = scope
        return .none

      case let .solo(.timeScopeChanged(timeScope)):
        state.vocab.timeScope = timeScope
        return .none

      case .solo:
        return .none

      case .vocab(.timeScopeChanged(.interesting)):
        return .none

      case let .vocab(.timeScopeChanged(timeScope)):
        state.solo.timeScope = timeScope
        return .none

      case let .vocab(.tappedRow(id)):
        enum CancelID { case fetch }

        guard state.vocab.resultEnvelope != nil
        else { return .none }

        return .run { send in
          await send(
            .fetchWordResponse(
              TaskResult {
                try await self.apiClient.apiRequest(
                  route: .leaderboard(.vocab(.fetchWord(wordId: .init(rawValue: id)))),
                  as: FetchVocabWordResponse.self
                )
              }
            )
          )
        }
        .cancellable(id: CancelID.fetch, cancelInFlight: true)

      case .vocab:
        return .none
      }
    }
    .ifLet(\.$destination, action: /Action.destination) {
      Destination()
    }

    Scope(state: \.solo, action: /Action.solo) {
      LeaderboardResults(loadResults: self.apiClient.loadSoloResults(gameMode:timeScope:))
    }
    Scope(state: \.vocab, action: /Action.vocab) {
      LeaderboardResults(loadResults: self.apiClient.loadVocabResults(gameMode:timeScope:))
    }
  }
}

public struct LeaderboardView: View {
  @Environment(\.colorScheme) var colorScheme
  let store: StoreOf<Leaderboard>
  @ObservedObject var viewStore: ViewStoreOf<Leaderboard>

  public init(store: StoreOf<Leaderboard>) {
    self.store = store
    self.viewStore = ViewStore(self.store, observe: { $0 })
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: .grid(10)) {
      HStack {
        ForEach(LeaderboardScope.allCases, id: \.self) { scope in
          Button(
            action: {
              self.viewStore.send(.scopeTapped(scope), animation: .default)
            }
          ) {
            Text(scope.title)
              .foregroundColor(self.viewStore.state.scope == scope ? scope.color : nil)
              .opacity(self.viewStore.state.scope == scope ? 1 : 0.3)
          }
        }
      }
      .foregroundColor(.hex(0xA3A3A3))
      .adaptiveFont(.matterMedium, size: 32)
      .screenEdgePadding(.horizontal)

      Group {
        switch self.viewStore.state.scope {
        case .games:
          LeaderboardResultsView(
            store: self.store.scope(state: \.solo, action: { .solo($0) }),
            title: Text("Solo"),
            subtitle: Text("\(self.viewStore.solo.resultEnvelope?.outOf ?? 0) players"),
            isFilterable: true,
            color: .isowordsOrange,
            timeScopeLabel: Text(self.viewStore.solo.timeScope.displayTitle),
            timeScopeMenu: VStack(alignment: .trailing, spacing: .grid(2)) {
              ForEach([TimeScope.lastDay, .lastWeek, .allTime], id: \.self) { scope in
                Button(scope.displayTitle) {
                  self.viewStore.send(.solo(.timeScopeChanged(scope)), animation: .default)
                }
                .disabled(self.viewStore.solo.timeScope == scope)
                .opacity(self.viewStore.solo.timeScope == scope ? 0.3 : 1)
              }
              .padding(.leading, .grid(12))
            }
          )

        case .vocab:
          LeaderboardResultsView(
            store: self.store.scope(state: \.vocab, action: { .vocab($0) }),
            title: (self.viewStore.vocab.resultEnvelope?.outOf).flatMap {
              $0 == 0 ? nil : Text("\($0) words")
            },
            subtitle: nil,
            isFilterable: false,
            color: .isowordsRed,
            timeScopeLabel: Text(self.viewStore.vocab.timeScope.displayTitle),
            timeScopeMenu: VStack(alignment: .trailing, spacing: .grid(2)) {
              ForEach([TimeScope.lastDay, .lastWeek, .allTime, .interesting], id: \.self) { scope in
                Button(scope.displayTitle) {
                  self.viewStore.send(.vocab(.timeScopeChanged(scope)), animation: .default)
                }
                .disabled(self.viewStore.vocab.timeScope == scope)
                .opacity(self.viewStore.vocab.timeScope == scope ? 0.3 : 1)
              }
              .padding(.leading, .grid(12))
            }
          )
        }
      }
      .padding(.top, .grid(4))
      .adaptivePadding(.bottom)
      .screenEdgePadding(.horizontal)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .navigationStyle(
      foregroundColor: self.colorScheme == .light
        ? .hex(0x393939)
        : self.viewStore.state.scope == .games
          ? .isowordsOrange
          : .isowordsRed,
      title: Text("Leaderboards")
    )
    .sheet(
      store: self.store.scope(state: \.$destination, action: { .destination($0) }),
      state: /Leaderboard.Destination.State.cubePreview,
      action: Leaderboard.Destination.Action.cubePreview,
      content: CubePreviewView.init(store:)
    )
  }
}

extension ApiClient {
  @Sendable
  func loadSoloResults(
    gameMode: GameMode,
    timeScope: TimeScope
  ) async throws -> ResultEnvelope {
    let response = try await self.apiRequest(
      route: .leaderboard(
        .fetch(
          gameMode: gameMode,
          language: .en,
          timeScope: timeScope
        )
      ),
      as: FetchLeaderboardResponse.self
    )
    return response.entries.first.map { firstEntry in
      ResultEnvelope(
        outOf: firstEntry.outOf,
        results: response.entries.map { entry in
          ResultEnvelope.Result(
            denseRank: entry.rank,
            id: entry.id.rawValue,
            isYourScore: entry.isYourScore,
            rank: entry.rank,
            score: entry.score,
            subtitle: nil,
            title: entry.playerDisplayName ?? (entry.isYourScore ? "You" : "Someone")
          )
        }
      )
    }
      ?? .init()
  }
}

extension ApiClient {
  @Sendable
  func loadVocabResults(
    gameMode: GameMode,
    timeScope: TimeScope
  ) async throws -> ResultEnvelope {
    let response = try await self.apiRequest(
      route: .leaderboard(
        .vocab(
          .fetch(
            language: .en,
            timeScope: timeScope
          )
        )
      ),
      as: [FetchVocabLeaderboardResponse.Entry].self
    )
    return response.first.map { firstEntry in
      ResultEnvelope(
        outOf: firstEntry.outOf,
        results: response.map(ResultEnvelope.Result.init)
      )
    }
      ?? .init()
  }
}

extension ResultEnvelope.Result {
  public init(_ entry: FetchVocabLeaderboardResponse.Entry) {
    self.init(
      denseRank: entry.denseRank,
      id: entry.wordId.rawValue,
      isYourScore: entry.isYourScore,
      rank: entry.rank,
      score: entry.score,
      subtitle: entry.playerDisplayName ?? (entry.isYourScore ? "You" : "Someone"),
      title: entry.word.capitalized
    )
  }
}

#if DEBUG
  import Overture
  import SwiftUIHelpers

  struct LeaderboardView_Previews: PreviewProvider {
    static var previews: some View {
      Preview {
        NavigationView {
          LeaderboardView(
            store: Store(initialState: Leaderboard.State()) {
              Leaderboard().dependency(
                \.apiClient,
                update(.noop) {
                  $0.apiRequest = { @Sendable route in
                    switch route {
                    case .leaderboard(.fetch(gameMode: _, language: _, timeScope: _)):
                      try await Task.sleep(nanoseconds: NSEC_PER_SEC)
                      return try await OK(
                        FetchLeaderboardResponse(
                          entries: (1...20).map { idx in
                            FetchLeaderboardResponse.Entry(
                              id: .init(rawValue: .init()),
                              isSupporter: idx == 2,
                              isYourScore: false,
                              outOf: 100,
                              playerDisplayName: "Blob",
                              rank: idx,
                              score: 5000 - idx * 233
                            )
                          }
                        )
                      )

                    default:
                      throw CancellationError()
                    }
                  }
                }
              )
            }
          )
        }
      }
    }
  }
#endif
