import ApiClient
import AudioPlayerClient
import ComposableArchitecture
import CubeCore
import CubePreview
import FeedbackGeneratorClient
import LowPowerModeClient
import SharedModels
import Styleguide
import SwiftUI
import TcaHelpers

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
  public var isAnimationReduced: Bool
  public var isHapticsEnabled: Bool
  public var scope: LeaderboardScope = .games
  public var settings: CubeSceneView.ViewState.Settings
  public var solo: LeaderboardResultsState<TimeScope> = .init(timeScope: .lastWeek)
  public var vocab: LeaderboardResultsState<TimeScope> = .init(timeScope: .lastWeek)

  public var isCubePreviewPresented: Bool { self.cubePreview != nil }

  public init(
    cubePreview: CubePreviewState? = nil,
    isAnimationReduced: Bool = false,
    isHapticsEnabled: Bool,
    scope: LeaderboardScope = .games,
    settings: CubeSceneView.ViewState.Settings,
    solo: LeaderboardResultsState<TimeScope> = .init(timeScope: .lastWeek),
    vocab: LeaderboardResultsState<TimeScope> = .init(timeScope: .lastWeek)
  ) {
    self.cubePreview = cubePreview
    self.isAnimationReduced = isAnimationReduced
    self.isHapticsEnabled = isHapticsEnabled
    self.scope = scope
    self.settings = settings
    self.solo = solo
    self.vocab = vocab
  }
}

public enum LeaderboardAction: Equatable {
  case cubePreview(CubePreviewAction)
  case dismissCubePreview
  case fetchWordResponse(TaskResult<FetchVocabWordResponse>)
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
          lowPowerMode: $0.lowPowerMode,
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
          loadResults: $0.apiClient.loadSoloResults(gameMode:timeScope:)
        )
      }
    ),

  Reducer.leaderboardResultsReducer()
    .pullback(
      state: \LeaderboardState.vocab,
      action: /LeaderboardAction.vocab,
      environment: {
        LeaderboardResultsEnvironment(
          loadResults: $0.apiClient.loadVocabResults(gameMode:timeScope:)
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
        isAnimationReduced: state.isAnimationReduced,
        isHapticsEnabled: state.isHapticsEnabled,
        moveIndex: response.moveIndex,
        moves: response.moves,
        settings: state.settings
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
      enum CancelID {}

      guard let resultEnvelope = state.vocab.resultEnvelope
      else { return .none }

      return .task {
        await .fetchWordResponse(
          TaskResult {
            try await environment.apiClient.apiRequestAsync(
              route: .leaderboard(.vocab(.fetchWord(wordId: .init(rawValue: id)))),
              as: FetchVocabWordResponse.self
            )
          }
        )
      }
      .cancellable(id: CancelID.self, cancelInFlight: true)

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
  @Sendable
  func loadSoloResults(
    gameMode: GameMode,
    timeScope: TimeScope
  ) async throws -> ResultEnvelope {
    let response = try await self.apiRequestAsync(
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
    let response = try await self.apiRequestAsync(
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
            store: .init(
              initialState: LeaderboardState(
                isAnimationReduced: false,
                isHapticsEnabled: true,
                settings: .init()
              ),
              reducer: leaderboardReducer,
              environment: LeaderboardEnvironment(
                apiClient: update(.noop) {
                  $0.apiRequestAsync = { @Sendable route in
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
                },
                audioPlayer: .noop,
                feedbackGenerator: .noop,
                lowPowerMode: .false,
                mainQueue: .main
              )
            )
          )
        }
      }
    }
  }
#endif
