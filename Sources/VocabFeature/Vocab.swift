import ComposableArchitecture
import CubePreview
import LocalDatabaseClient
import SwiftUI

@Reducer
public struct Vocab: Reducer {
  @Reducer
  public struct Destination: Reducer {
    public enum State: Equatable {
      case cubePreview(CubePreview.State)
    }

    public enum Action: Equatable {
      case cubePreview(CubePreview.Action)
    }

    public var body: some ReducerOf<Self> {
      Scope(state: \.cubePreview, action: \.cubePreview) {
        CubePreview()
      }
    }
  }

  public struct State: Equatable {
    @PresentationState var destination: Destination.State?
    var isAnimationReduced: Bool
    var vocab: LocalDatabaseClient.Vocab?

    public init(
      destination: Destination.State? = nil,
      isAnimationReduced: Bool,
      vocab: LocalDatabaseClient.Vocab? = nil
    ) {
      self.destination = destination
      self.isAnimationReduced = isAnimationReduced
      self.vocab = vocab
    }

    public struct GamesResponse: Equatable {
      var games: [LocalDatabaseClient.Game]
      var word: String
    }
  }

  public enum Action: Equatable {
    case destination(PresentationAction<Destination.Action>)
    case gamesResponse(TaskResult<State.GamesResponse>)
    case task
    case vocabResponse(TaskResult<LocalDatabaseClient.Vocab>)
    case wordTapped(LocalDatabaseClient.Vocab.Word)
  }

  @Dependency(\.database) var database

  public init() {}

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .destination:
        return .none

      case .gamesResponse(.failure):
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

        state.destination = .cubePreview(
          CubePreview.State(
            cubes: game.completedGame.cubes,
            moveIndex: moveIndex,
            moves: game.completedGame.moves
          )
        )
        return .none

      case .task:
        return .run { send in
          await send(.vocabResponse(TaskResult { try await self.database.fetchVocab() }))
        }

      case let .vocabResponse(.success(vocab)):
        state.vocab = vocab
        return .none

      case .vocabResponse(.failure):
        return .none

      case let .wordTapped(word):
        return .run { send in
          await send(
            .gamesResponse(
              TaskResult {
                .init(
                  games: try await self.database.fetchGamesForWord(word.letters),
                  word: word.letters
                )
              }
            )
          )
        }
      }
    }
    .ifLet(\.$destination, action: \.destination) {
      Destination()
    }
  }
}

public struct VocabView: View {
  public let store: StoreOf<Vocab>

  public init(store: StoreOf<Vocab>) {
    self.store = store
  }

  public var body: some View {
    VStack {
      IfLetStore(self.store.scope(state: \.vocab, action: { $0 })) { vocabStore in
        WithViewStore(vocabStore, observe: { $0 }) { vocabViewStore in
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
      .task { await self.store.send(.task).finish() }
      .sheet(
        store: self.store.scope(state: \.$destination, action: \.destination),
        state: \.cubePreview,
        action: { .cubePreview($0) },
        content: CubePreviewView.init(store:)
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

  extension Store where State == Vocab.State, Action == Vocab.Action {
    static let vocab = Store(
      initialState: Vocab.State(
        destination: nil,
        isAnimationReduced: false,
        vocab: .init(
          words: [
            .init(letters: "STENOGRAPHER", playCount: 1, score: 1_230),
            .init(letters: "PUZZLE", playCount: 10, score: 560),
          ]
        )
      )
    ) {
      Vocab()
    }
  }
#endif
