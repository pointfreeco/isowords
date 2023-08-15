import ComposableArchitecture
import CubePreview
import LocalDatabaseClient
import SwiftUI

public struct Vocab: ReducerProtocol {
  public struct State: Equatable {
    var cubePreview: CubePreview.State?
    var isAnimationReduced: Bool
    var isHapticsEnabled: Bool
    var vocab: LocalDatabaseClient.Vocab?

    public init(
      cubePreview: CubePreview.State? = nil,
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

  public enum Action: Equatable {
    case dismissCubePreview
    case gamesResponse(TaskResult<State.GamesResponse>)
    case preview(CubePreview.Action)
    case task
    case vocabResponse(TaskResult<LocalDatabaseClient.Vocab>)
    case wordTapped(LocalDatabaseClient.Vocab.Word)
  }

  @Dependency(\.database) var database

  public init() {}

  public var body: some ReducerProtocol<State, Action> {
    Reduce { state, action in
      switch action {
      case .dismissCubePreview:
        state.cubePreview = nil
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

        state.cubePreview = CubePreview.State(
          cubes: game.completedGame.cubes,
          isAnimationReduced: state.isAnimationReduced,
          isHapticsEnabled: state.isHapticsEnabled,
          moveIndex: moveIndex,
          moves: game.completedGame.moves,
          settings: .init()
        )
        return .none

      case .preview:
        return .none

      case .task:
        return .task {
          await .vocabResponse(TaskResult { try await self.database.fetchVocab() })
        }

      case let .vocabResponse(.success(vocab)):
        state.vocab = vocab
        return .none

      case .vocabResponse(.failure):
        return .none

      case let .wordTapped(word):
        return .task {
          await .gamesResponse(
            TaskResult {
              .init(
                games: try await self.database.fetchGamesForWord(word.letters),
                word: word.letters
              )
            }
          )
        }
      }
    }
    .ifLet(\.cubePreview, action: /Action.preview) {
      CubePreview()
    }
  }
}

public struct VocabView: View {
  public let store: StoreOf<Vocab>

  public init(store: StoreOf<Vocab>) {
    self.store = store
  }

  public var body: some View {
    WithViewStore(self.store, observe: { $0 }) { viewStore in
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
      }
      .task { await viewStore.send(.task).finish() }
      .sheet(
        isPresented: viewStore.binding(
          get: { $0.cubePreview != nil },
          send: .dismissCubePreview
        )
      ) {
        IfLetStore(
          self.store.scope(state: \.cubePreview, action: Vocab.Action.preview),
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

  extension Store where State == Vocab.State, Action == Vocab.Action {
    static let vocab = Store(
      initialState: Vocab.State(
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
      reducer: Vocab()
    )
  }
#endif
