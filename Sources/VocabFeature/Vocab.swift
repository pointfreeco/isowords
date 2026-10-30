import ComposableArchitecture
import CubePreview
import Dependencies
import LocalDatabaseClient
import SwiftUI

@Feature
public struct Vocab {
  @Feature
  public enum Destination {
    case cubePreview(CubePreview)
  }

  public struct State {
    @DebugSnapshotTracked var destination: Destination.State?
    @DebugSnapshotTracked var isAnimationReduced: Bool
    @DebugSnapshotTracked var vocab: LocalDatabaseClient.Vocab?

    public init(
      destination: Destination.State? = nil,
      isAnimationReduced: Bool,
      vocab: LocalDatabaseClient.Vocab? = nil
    ) {
      self.destination = destination
      self.isAnimationReduced = isAnimationReduced
      self.vocab = vocab
    }
  }

  public enum Action {
    case destination(Destination.Action)
    case wordTapped(LocalDatabaseClient.Vocab.Word)
  }

  @Dependency(\.database) var database

  public init() {}

  public var body: some Feature {
    Update { state, action in
      switch action {
      case .destination:
        break

      case let .wordTapped(word):
        store.addTask {
          guard
            let game = try await database.fetchGamesForWord(word.letters).first,
            let moveIndex = game.completedGame.moves.firstIndex(where: { move in
              switch move.type {
              case let .playedWord(cubeFaces):
                return game.completedGame.cubes.string(from: cubeFaces) == word.letters
              case .removedCube:
                return false
              }
            })
          else { return }

          try store.modify {
            $0.destination = .cubePreview(
              CubePreview.State(
                cubes: game.completedGame.cubes,
                moveIndex: moveIndex,
                moves: game.completedGame.moves
              )
            )
          }
        }
      }
    }
    .ifLet(\.destination) {
      Destination.body
    }
    .onMount { _ in
      store.addTask {
        let vocab = try await database.fetchVocab()
        try store.modify { $0.vocab = vocab }
      }
    }
  }
}

public struct VocabView: View {
  @Bindable var store: StoreOf<Vocab>

  public init(store: StoreOf<Vocab>) {
    self.store = store
  }

  public var body: some View {
    VStack {
      if let words = store.vocab?.words {
        List {
          ForEach(words, id: \.letters) { word in
            Button {
              store.send(.wordTapped(word))
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
    .sheet(item: $store.scope(\.destination).cubePreview) { store in
      CubePreviewView(store: store)
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
