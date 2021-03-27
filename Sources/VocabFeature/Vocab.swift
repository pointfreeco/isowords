import ComposableArchitecture
import CubePreview
import FeedbackGeneratorClient
import LocalDatabaseClient
import SharedModels
import Styleguide
import SwiftUI

public struct VocabState: Equatable {
  var cubePreview: CubePreviewState?
  var vocab: LocalDatabaseClient.Vocab?

  public init(
    cubePreview: CubePreviewState? = nil,
    vocab: LocalDatabaseClient.Vocab? = nil
  ) {
    self.cubePreview = cubePreview
    self.vocab = vocab
  }

  public struct GamesResponse: Equatable {
    var games: [LocalDatabaseClient.Game]
    var word: String
  }
}

public enum VocabAction: Equatable {
  case dismissCubePreview
  case gamesResponse(Result<VocabState.GamesResponse, NSError>)
  case onAppear
  case preview(CubePreviewAction)
  case vocabResponse(Result<LocalDatabaseClient.Vocab, NSError>)
  case wordTapped(LocalDatabaseClient.Vocab.Word)
}

public struct VocabEnvironment {
  var database: LocalDatabaseClient
  var feedbackGenerator: FeedbackGeneratorClient
  var mainQueue: AnySchedulerOf<DispatchQueue>

  public init(
    database: LocalDatabaseClient,
    feedbackGenerator: FeedbackGeneratorClient,
    mainQueue: AnySchedulerOf<DispatchQueue>
  ) {
    self.database = database
    self.feedbackGenerator = feedbackGenerator
    self.mainQueue = mainQueue
  }
}

public let vocabReducer = Reducer<
  VocabState,
  VocabAction,
  VocabEnvironment
>.combine(
  cubePreviewReducer
    .optional()
    .pullback(
      state: \.cubePreview,
      action: /VocabAction.preview,
      environment: {
        CubePreviewEnvironment(
          feedbackGenerator: $0.feedbackGenerator,
          mainQueue: $0.mainQueue
        )
      }
    ),

  .init { state, action, environment in
    switch action {
    case .dismissCubePreview:
      state.cubePreview = nil
      return .none

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
        isOnLowPowerMode: false, // TODO
        moves: game.completedGame.moves,
        moveIndex: moveIndex,
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
        isPresented: viewStore.binding(
          get: { $0.cubePreview != nil },
          send: .dismissCubePreview
        )
      ) {
        IfLetStore(
          self.store.scope(state: \.cubePreview, action: VocabAction.preview),
          then: CubePreviewView.init(store:)
        )
      }
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
        vocab: .init(
          words: [
            .init(letters: "STENOGRAPHER", playCount: 1, score: 1_230),
            .init(letters: "PUZZLE", playCount: 10, score: 560),
          ]
        )
      ),
      reducer: vocabReducer,
      environment: .init(
        database: .noop,
        feedbackGenerator: .noop,
        mainQueue: DispatchQueue.main.eraseToAnyScheduler()
      )
    )
  }
#endif
