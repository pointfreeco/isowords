import AudioPlayerClient
import ComposableArchitecture
import CubePreview
import FeedbackGeneratorClient
import LocalDatabaseClient
import LowPowerModeClient
import SharedModels
import Styleguide
import SwiftUI

public struct VocabState: Equatable {
  var cubePreview: CubePreviewState?
  var isAnimationReduced: Bool
  var isHapticsEnabled: Bool
  var vocab: LocalDatabaseClient.Vocab?

  public init(
    cubePreview: CubePreviewState? = nil,
    isAnimationReduced: Bool,
    isHapticsEnabled: Bool,
    vocab: LocalDatabaseClient.Vocab? = nil
  ) {
    self.cubePreview = cubePreview
    self.isAnimationReduced = isAnimationReduced
    self.isHapticsEnabled = isHapticsEnabled
    self.vocab = vocab
  }

  public struct GamesResponse: Equatable {
    var games: [LocalDatabaseClient.Game]
    var word: String
  }
}

public enum VocabAction: Equatable {
  case gamesResponse(Result<VocabState.GamesResponse, NSError>)
  case onAppear
  case preview(PresentationAction<CubePreviewAction>)
  case vocabResponse(Result<LocalDatabaseClient.Vocab, NSError>)
  case wordTapped(LocalDatabaseClient.Vocab.Word)
}

public struct VocabEnvironment {
  var audioPlayer: AudioPlayerClient
  var database: LocalDatabaseClient
  var feedbackGenerator: FeedbackGeneratorClient
  var lowPowerMode: LowPowerModeClient
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
    self.lowPowerMode = lowPowerMode
    self.feedbackGenerator = feedbackGenerator
    self.mainQueue = mainQueue
  }
}

public let vocabReducer = Reducer<VocabState, VocabAction, VocabEnvironment>
{ state, action, environment in
  switch action {
  case let .gamesResponse(.failure(error)):
    return .none

  case let .gamesResponse(.success(response)):
    guard let game = response.games.first
    else { return .none }

    let possibleMoveIndex = game.completedGame.moves.firstIndex { move in
      switch move.type {
      case let .playedWord(cubeFaces):
        return game.completedGame.cubes.string(from: cubeFaces) == response.word
      case .removedCube:
        return false
      }
    }
    guard let moveIndex = possibleMoveIndex
    else { return .none }

    state.cubePreview = .init(
      cubes: game.completedGame.cubes,
      isAnimationReduced: state.isAnimationReduced,
      isHapticsEnabled: state.isHapticsEnabled,
      moveIndex: moveIndex,
      moves: game.completedGame.moves,
      settings: .init()
    )
    return .none

  case .onAppear:
    return environment.database.fetchVocab
      .mapError { $0 as NSError }
      .catchToEffect()
      .map(VocabAction.vocabResponse)

  case .preview:
    return .none

  case let .vocabResponse(.success(vocab)):
    state.vocab = vocab
    return .none

  case let .vocabResponse(.failure(error)):
    return .none

  case let .wordTapped(word):
    return environment.database.fetchGamesForWord(word.letters)
      .map { .init(games: $0, word: word.letters) }
      .mapError { $0 as NSError }
      .catchToEffect()
      .map(VocabAction.gamesResponse)
  }
}
.presents(
  cubePreviewReducer,
  state: \.cubePreview,
  action: /VocabAction.preview,
  environment: {
    CubePreviewEnvironment(
      audioPlayer: $0.audioPlayer,
      feedbackGenerator: $0.feedbackGenerator,
      lowPowerMode: $0.lowPowerMode,
      mainQueue: $0.mainQueue
    )
  }
)

public struct VocabView: View {
  public let store: Store<VocabState, VocabAction>

  public init(store: Store<VocabState, VocabAction>) {
    self.store = store
  }

  public var body: some View {
    WithViewStore(self.store) { viewStore in
      VStack {
        IfLetStore(self.store.scope(state: \.vocab)) { vocabStore in
          WithViewStore(vocabStore) { vocabViewStore in
            List {
              ForEach(vocabViewStore.words, id: \.letters) { word in
                Button {
                  vocabViewStore.send(.wordTapped(word))
                } label: {
                  HStack {
                    HStack(alignment: .top, spacing: 0) {
                      Text(word.letters.capitalized)
                        .adaptiveFont(.matterMedium, size: 20)

                      Text("\(word.score)")
                        .padding(.top, -4)
                        .adaptiveFont(.matterMedium, size: 14)
                    }

                    Spacer()

                    if word.playCount > 1 {
                      Text("(\(word.playCount)x)")
                    }
                  }
                }
              }
            }
          }
        }
      }
      .onAppear { viewStore.send(.onAppear) }
      .sheet(
        ifLet: self.store.scope(state: \.cubePreview, action: VocabAction.preview),
        then: CubePreviewView.init(store:)
      )
    }
    .adaptiveFont(.matterMedium, size: 16)
    .navigationStyle(title: Text("Words Found"))
  }
}

#if DEBUG
  @testable import LocalDatabaseClient

  struct VocabView_Previews: PreviewProvider {
    static var previews: some View {
      Group {
        NavigationView {
          VocabView(store: .vocab)
        }
        .environment(\.colorScheme, .light)

        NavigationView {
          VocabView(store: .vocab)
        }
        .environment(\.colorScheme, .dark)
      }
    }
  }

  extension Store where State == VocabState, Action == VocabAction {
    static let vocab = Store(
      initialState: .init(
        cubePreview: nil,
        isAnimationReduced: false,
        isHapticsEnabled: false,
        vocab: .init(
          words: [
            .init(letters: "STENOGRAPHER", playCount: 1, score: 1_230),
            .init(letters: "PUZZLE", playCount: 10, score: 560),
          ]
        )
      ),
      reducer: vocabReducer,
      environment: .init(
        audioPlayer: .noop,
        database: .noop,
        feedbackGenerator: .noop,
        lowPowerMode: .false,
        mainQueue: .main
      )
    )
  }
#endif
