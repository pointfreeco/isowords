import ComposableArchitecture
import LocalDatabaseClient
import Styleguide
import SwiftUI
import VocabFeature

@Reducer
public struct Stats {
  @Reducer
  public struct Destination {
    public enum State: Equatable {
      case vocab(Vocab.State)
    }

    public enum Action {
      case vocab(Vocab.Action)
    }

    public var body: some ReducerOf<Self> {
      Scope(state: \.vocab, action: \.vocab) {
        Vocab()
      }
    }
  }

  public struct State: Equatable {
    public var averageWordLength: Double?
    @PresentationState public var destination: Destination.State?
    public var gamesPlayed: Int
    public var highestScoringWord: LocalDatabaseClient.Stats.Word?
    public var highScoreTimed: Int?
    public var highScoreUnlimited: Int?
    public var isAnimationReduced: Bool
    public var longestWord: String?
    public var secondsPlayed: Int
    public var wordsFound: Int

    public init(
      averageWordLength: Double? = nil,
      destination: Destination.State? = nil,
      gamesPlayed: Int = 0,
      highestScoringWord: LocalDatabaseClient.Stats.Word? = nil,
      highScoreTimed: Int? = nil,
      highScoreUnlimited: Int? = nil,
      isAnimationReduced: Bool = false,
      longestWord: String? = nil,
      secondsPlayed: Int = 0,
      wordsFound: Int = 0
    ) {
      self.averageWordLength = averageWordLength
      self.destination = destination
      self.gamesPlayed = gamesPlayed
      self.highestScoringWord = highestScoringWord
      self.highScoreTimed = highScoreTimed
      self.highScoreUnlimited = highScoreUnlimited
      self.isAnimationReduced = isAnimationReduced
      self.longestWord = longestWord
      self.secondsPlayed = secondsPlayed
      self.wordsFound = wordsFound
    }
  }

  public enum Action {
    case backButtonTapped
    case destination(PresentationAction<Destination.Action>)
    case statsResponse(Result<LocalDatabaseClient.Stats, Error>)
    case task
    case vocabButtonTapped
  }

  @Dependency(\.database) var database

  public init() {}

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .backButtonTapped:
        return .none

      case .destination:
        return .none

      case .statsResponse(.failure):
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

      case .task:
        return .run { send in
          await send(.statsResponse(Result { try await self.database.fetchStats() }))
        }

      case .vocabButtonTapped:
        state.destination = .vocab(
          .init(
            isAnimationReduced: state.isAnimationReduced
          )
        )
        return .none
      }
    }
    .ifLet(\.$destination, action: \.destination) {
      Destination()
    }
  }
}

public struct StatsView: View {
  let store: StoreOf<Stats>
  @ObservedObject var viewStore: ViewStoreOf<Stats>

  public init(store: StoreOf<Stats>) {
    self.store = store
    self.viewStore = ViewStore(store, observe: { $0 })
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
        Button {
          self.viewStore.send(.vocabButtonTapped)
        } label: {
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
    .navigationDestination(
      store: self.store.scope(state: \.$destination.vocab, action: \.destination.vocab),
      destination: VocabView.init(store:)
    )
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
              initialState: Stats.State(
                averageWordLength: 5,
                gamesPlayed: 1234,
                highestScoringWord: .init(letters: "ENFEEBLINGS", score: 1022),
                isAnimationReduced: false,
                longestWord: "ENFEEBLINGS",
                secondsPlayed: 42000,
                wordsFound: 200
              )
            ) {
              Stats()
            }
          )
          .navigationBarHidden(true)
        }
      }
    }
  }
#endif
