import AudioPlayerClient
import ComposableArchitecture
import FeedbackGeneratorClient
import LocalDatabaseClient
import LowPowerModeClient
import SharedModels
import Styleguide
import SwiftUI
import VocabFeature

public struct StatsState: Equatable {
  public var averageWordLength: Double?
  public var gamesPlayed: Int
  public var highestScoringWord: LocalDatabaseClient.Stats.Word?
  public var highScoreTimed: Int?
  public var highScoreUnlimited: Int?
  public var isAnimationReduced: Bool
  public var isHapticsEnabled: Bool
  public var longestWord: String?
  public var route: Route?
  public var secondsPlayed: Int
  public var wordsFound: Int

  public enum Route: Equatable {
    case vocab(Vocab.State)

    public enum Tag: Int {
      case vocab
    }

    var tag: Tag {
      switch self {
      case .vocab:
        return .vocab
      }
    }
  }

  public init(
    averageWordLength: Double? = nil,
    gamesPlayed: Int = 0,
    highestScoringWord: LocalDatabaseClient.Stats.Word? = nil,
    highScoreTimed: Int? = nil,
    highScoreUnlimited: Int? = nil,
    isAnimationReduced: Bool = false,
    isHapticsEnabled: Bool = true,
    longestWord: String? = nil,
    route: Route? = nil,
    secondsPlayed: Int = 0,
    wordsFound: Int = 0
  ) {
    self.averageWordLength = averageWordLength
    self.gamesPlayed = gamesPlayed
    self.highestScoringWord = highestScoringWord
    self.highScoreTimed = highScoreTimed
    self.highScoreUnlimited = highScoreUnlimited
    self.isAnimationReduced = isAnimationReduced
    self.isHapticsEnabled = isHapticsEnabled
    self.longestWord = longestWord
    self.route = route
    self.secondsPlayed = secondsPlayed
    self.wordsFound = wordsFound
  }
}

public enum StatsAction: Equatable {
  case backButtonTapped
  case setNavigation(tag: StatsState.Route.Tag?)
  case statsResponse(TaskResult<LocalDatabaseClient.Stats>)
  case task
  case vocab(Vocab.Action)
}

public struct StatsEnvironment {
  var audioPlayer: AudioPlayerClient
  var database: LocalDatabaseClient
  var lowPowerMode: LowPowerModeClient
  var feedbackGenerator: FeedbackGeneratorClient
  var mainQueue: AnySchedulerOf<DispatchQueue>

  public init(
    audioPlayer: AudioPlayerClient,
    database: LocalDatabaseClient,
    feedbackGenerator: FeedbackGeneratorClient,
    lowPowerMode: LowPowerModeClient,
    mainQueue: AnySchedulerOf<DispatchQueue>
  ) {
    self.audioPlayer = audioPlayer
    self.database = database
    self.feedbackGenerator = feedbackGenerator
    self.lowPowerMode = lowPowerMode
    self.mainQueue = mainQueue
  }
}

public let statsReducer: Reducer<StatsState, StatsAction, StatsEnvironment> = .combine(
  Reducer(
    EmptyReducer().ifLet(state: \.route, action: .self) {
      EmptyReducer().ifLet(
        state: /StatsState.Route.vocab,
        action: /StatsAction.vocab
      ) {
        Vocab()
      }
    }
  ),

  .init { state, action, environment in
    switch action {
    case .backButtonTapped:
      return .none

    case let .statsResponse(.failure(error)):
      // TODO
      return .none

    case let .statsResponse(.success(stats)):
      state.averageWordLength = stats.averageWordLength
      state.gamesPlayed = stats.gamesPlayed
      state.highestScoringWord = stats.highestScoringWord
      state.highScoreTimed = stats.highScoreTimed
      state.highScoreUnlimited = stats.highScoreUnlimited
      state.longestWord = stats.longestWord
      state.secondsPlayed = stats.secondsPlayed
      state.wordsFound = stats.wordsFound
      return .none

    case .setNavigation(tag: .vocab):
      state.route = .vocab(
        .init(
          isAnimationReduced: state.isAnimationReduced,
          isHapticsEnabled: state.isHapticsEnabled
        )
      )
      return .none

    case .setNavigation(tag: .none):
      state.route = nil
      return .none

    case .task:
      return .task {
        await .statsResponse(TaskResult { try await environment.database.fetchStats() })
      }

    case .vocab:
      return .none
    }
  }
)

public struct StatsView: View {
  let store: Store<StatsState, StatsAction>
  @ObservedObject var viewStore: ViewStore<StatsState, StatsAction>

  public init(store: Store<StatsState, StatsAction>) {
    self.store = store
    self.viewStore = ViewStore(store)
  }

  public var body: some View {
    SettingsForm {
      SettingsRow {
        HStack {
          Text("Games played")
          Spacer()
          Text("\(self.viewStore.gamesPlayed)")
            .foregroundColor(.isowordsOrange)
        }
        .adaptiveFont(.matterMedium, size: 16)
      }

      SettingsRow {
        VStack(alignment: .leading) {
          Text("Top scores")
            .adaptiveFont(.matterMedium, size: 16)

          VStack(alignment: .leading) {
            HStack {
              Text("Timed")
              Spacer()
              Group {
                if let highScoreTimed = self.viewStore.highScoreTimed {
                  Text("\(highScoreTimed)")
                } else {
                  Text("none")
                }
              }
              .foregroundColor(.isowordsOrange)
            }
            Divider()
            HStack {
              Text("Unlimited")
              Spacer()
              Group {
                if let highScoreUnlimited = self.viewStore.highScoreUnlimited {
                  Text("\(highScoreUnlimited)")
                } else {
                  Text("none")
                }
              }
              .foregroundColor(.isowordsOrange)
            }
          }
          .adaptiveFont(.matterMedium, size: 16)
          .padding([.leading, .top])
        }
      }

      SettingsRow {
        NavigationLink(
          destination: IfLetStore(
            self.store.scope(
              state: (\StatsState.route).appending(path: /StatsState.Route.vocab).extract(from:),
              action: StatsAction.vocab
            ),
            then: VocabView.init(store:)
          ),
          tag: StatsState.Route.Tag.vocab,
          selection: self.viewStore.binding(
            get: \.route?.tag,
            send: StatsAction.setNavigation(tag:)
          )
        ) {
          HStack {
            Text("Words found")
            Spacer()
            Group {
              Text("\(self.viewStore.wordsFound)")
              Image(systemName: "arrow.right")
            }
            .foregroundColor(.isowordsOrange)
          }
          .adaptiveFont(.matterMedium, size: 16)
          .background(Color.adaptiveWhite)
        }
        .buttonStyle(PlainButtonStyle())
      }

      if let highestScoringWord = self.viewStore.highestScoringWord {
        SettingsRow {
          VStack(alignment: .trailing, spacing: 12) {
            HStack {
              Text("Best word")
                .adaptiveFont(.matterMedium, size: 16)
              Spacer()
              HStack(alignment: .top, spacing: 0) {
                Text(highestScoringWord.letters.capitalized)
                  .adaptiveFont(.matterMedium, size: 16)

                Text("\(highestScoringWord.score)")
                  .padding(.top, -4)
                  .adaptiveFont(.matterMedium, size: 12)
              }
              .foregroundColor(.isowordsOrange)
            }
          }
        }
      }

      SettingsRow {
        HStack {
          Text("Time played")
          Spacer()
          Text(timePlayed(seconds: self.viewStore.secondsPlayed))
            .foregroundColor(.isowordsOrange)
        }
        .adaptiveFont(.matterMedium, size: 16)
      }
    }
    .task { await self.viewStore.send(.task).finish() }
    .navigationStyle(title: Text("Stats"))
  }
}

private func timePlayed(seconds: Int) -> LocalizedStringKey {
  let hours = seconds / 60 / 60
  let minutes = (seconds / 60) % 60
  return "\(hours)h \(minutes)m"
}

#if DEBUG
  import SwiftUIHelpers

  @testable import LocalDatabaseClient

  struct StatsView_Previews: PreviewProvider {
    static var previews: some View {
      Preview {
        NavigationView {
          StatsView(
            store: Store(
              initialState: StatsState(
                averageWordLength: 5,
                gamesPlayed: 1234,
                highestScoringWord: .init(letters: "ENFEEBLINGS", score: 1022),
                isAnimationReduced: false,
                isHapticsEnabled: true,
                longestWord: "ENFEEBLINGS",
                secondsPlayed: 42000,
                wordsFound: 200
              ),
              reducer: statsReducer,
              environment: StatsEnvironment(
                audioPlayer: .noop,
                database: .noop,
                feedbackGenerator: .noop,
                lowPowerMode: .false,
                mainQueue: .main
              )
            )
          )
          .navigationBarHidden(true)
        }
      }
    }
  }
#endif
