import ApiClient
import AudioPlayerClient
import ComposableArchitecture
import CubePreview
import FeedbackGeneratorClient
import LowPowerModeClient
import SharedModels
import Styleguide
import SwiftUI

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

public struct LeaderboardState: Equatable {
  public var cubePreview: CubePreviewState?
  public var isOnLowPowerMode: Bool
  public var scope: LeaderboardScope = .games
  public var solo: LeaderboardResultsState<TimeScope> = .init(timeScope: .lastWeek)
  public var vocab: LeaderboardResultsState<TimeScope> = .init(timeScope: .lastWeek)

  public var isCubePreviewPresented: Bool { self.cubePreview != nil }

  public init(
    cubePreview: CubePreviewState? = nil,
    isOnLowPowerMode: Bool = false,
    scope: LeaderboardScope = .games,
    solo: LeaderboardResultsState<TimeScope> = .init(timeScope: .lastWeek),
    vocab: LeaderboardResultsState<TimeScope> = .init(timeScope: .lastWeek)
  ) {
    self.cubePreview = cubePreview
    self.isOnLowPowerMode = isOnLowPowerMode
    self.scope = scope
    self.solo = solo
    self.vocab = vocab
  }
}

public enum LeaderboardAction: Equatable {
  case cubePreview(CubePreviewAction)
  case dismissCubePreview
  case fetchWordResponse(Result<FetchVocabWordResponse, ApiError>)
  case scopeTapped(LeaderboardScope)
  case solo(LeaderboardResultsAction<TimeScope>)
  case vocab(LeaderboardResultsAction<TimeScope>)
}

public struct LeaderboardEnvironment {
  public var apiClient: ApiClient
  public var audioPlayer: AudioPlayerClient
  public var feedbackGenerator: FeedbackGeneratorClient
  public var lowPowerMode: LowPowerModeClient
  public var mainQueue: AnySchedulerOf<DispatchQueue>

  public init(
    apiClient: ApiClient,
    audioPlayer: AudioPlayerClient,
    feedbackGenerator: FeedbackGeneratorClient,
    lowPowerMode: LowPowerModeClient,
    mainQueue: AnySchedulerOf<DispatchQueue>
  ) {
    self.apiClient = apiClient
    self.audioPlayer = audioPlayer
    self.feedbackGenerator = feedbackGenerator
    self.lowPowerMode = lowPowerMode
    self.mainQueue = mainQueue
  }
}

#if DEBUG
  extension LeaderboardEnvironment {
    public static let failing = Self(
      apiClient: .failing,
      audioPlayer: .failing,
      feedbackGenerator: .failing,
      lowPowerMode: .failing,
      mainQueue: .failing("mainQueue")
    )
  }
#endif

public let leaderboardReducer = Reducer<
  LeaderboardState, LeaderboardAction, LeaderboardEnvironment
>.combine(

  cubePreviewReducer
    ._pullback(
      state: OptionalPath(\.cubePreview),
      action: /LeaderboardAction.cubePreview,
      environment: {
        CubePreviewEnvironment(
          audioPlayer: $0.audioPlayer,
          feedbackGenerator: $0.feedbackGenerator,
          mainQueue: $0.mainQueue
        )
      }
    ),

  Reducer.leaderboardResultsReducer()
    .pullback(
      state: \LeaderboardState.solo,
      action: /LeaderboardAction.solo,
      environment: {
        LeaderboardResultsEnvironment(
          loadResults: $0.apiClient.loadSoloResults(gameMode:timeScope:),
          mainQueue: $0.mainQueue
        )
      }
    ),

  Reducer.leaderboardResultsReducer()
    .pullback(
      state: \LeaderboardState.vocab,
      action: /LeaderboardAction.vocab,
      environment: {
        LeaderboardResultsEnvironment(
          loadResults: $0.apiClient.loadVocabResults(gameMode:timeScope:),
          mainQueue: $0.mainQueue
        )
      }
    ),

  .init { state, action, environment in
    switch action {
    case .cubePreview:
      return .none

    case .dismissCubePreview:
      state.cubePreview = nil
      return .none

    case .fetchWordResponse(.failure):
      return .none

    case let .fetchWordResponse(.success(response)):
      state.cubePreview = CubePreviewState(
        cubes: response.puzzle,
        isOnLowPowerMode: state.isOnLowPowerMode,
        moves: response.moves,
        moveIndex: response.moveIndex,
        settings: .init() // TODO
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
      struct CancelId: Hashable {}

      guard let resultEnvelope = state.vocab.resultEnvelope
      else { return .none }
      return environment.apiClient.apiRequest(
        route: .leaderboard(.vocab(.fetchWord(wordId: .init(rawValue: id)))),
        as: FetchVocabWordResponse.self
      )
      .receive(on: environment.mainQueue)
      .catchToEffect()
      .map(LeaderboardAction.fetchWordResponse)
      .cancellable(id: CancelId(), cancelInFlight: true)

    case .vocab:
      return .none
    }
  }
)

public struct LeaderboardView: View {
  @Environment(\.colorScheme) var colorScheme
  let store: Store<LeaderboardState, LeaderboardAction>
  @ObservedObject var viewStore: ViewStore<LeaderboardState, LeaderboardAction>

  public init(store: Store<LeaderboardState, LeaderboardAction>) {
    self.store = store
    self.viewStore = ViewStore(self.store)
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
            store: self.store.scope(
              state: \.solo,
              action: LeaderboardAction.solo
            ),
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
            store: self.store.scope(
              state: \.vocab,
              action: LeaderboardAction.vocab
            ),
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
      .adaptivePadding([.bottom])
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
      isPresented: self.viewStore.binding(get: \.isCubePreviewPresented, send: .dismissCubePreview)
    ) {
      IfLetStore(
        self.store.scope(state: \.cubePreview, action: LeaderboardAction.cubePreview),
        then: CubePreviewView.init(store:)
      )
    }
  }
}

extension ApiClient {
  func loadSoloResults(
    gameMode: GameMode,
    timeScope: TimeScope
  ) -> Effect<ResultEnvelope, ApiError> {
    self.apiRequest(
      route: .leaderboard(
        .fetch(
          gameMode: gameMode,
          language: .en,
          timeScope: timeScope
        )
      ),
      as: FetchLeaderboardResponse.self
    )
    .compactMap { response in
      response.entries.first.map { firstEntry in
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
    }
    .eraseToEffect()
  }
}

extension ApiClient {
  func loadVocabResults(
    gameMode: GameMode,
    timeScope: TimeScope
  ) -> Effect<ResultEnvelope, ApiError> {
    self.apiRequest(
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
    .compactMap { response in
      response.first.map { firstEntry in
        ResultEnvelope(
          outOf: firstEntry.outOf,
          results: response.map(ResultEnvelope.Result.init)
        )
      }
    }
    .eraseToEffect()
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
            store: .init(
              initialState: LeaderboardState(),
              reducer: leaderboardReducer,
              environment: LeaderboardEnvironment(
                apiClient: update(.noop) {
                  $0.apiRequest = { route in
                    switch route {
                    case .leaderboard(.fetch(gameMode: _, language: _, timeScope: _)):
                      return Effect.ok(
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
                      .delay(for: 1, scheduler: DispatchQueue.main)
                      .eraseToEffect()

                    default:
                      return .none
                    }
                  }
                },
                audioPlayer: .noop,
                feedbackGenerator: .noop,
                lowPowerMode: .false,
                mainQueue: DispatchQueue.main.eraseToAnyScheduler()
              )
            )
          )
        }
      }
    }
  }
#endif
