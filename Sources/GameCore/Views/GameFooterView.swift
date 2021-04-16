import ComposableArchitecture
import SharedModels
import Styleguide
import SwiftUI

public struct WordListState: Equatable {
  let isTurnBasedGame: Bool
  let selectedWordIsEmpty: Bool
  let words: [PlayedWord]
}

extension WordListState {
  init(gameState state: GameState) {
    self.isTurnBasedGame = state.turnBasedContext != nil
    self.selectedWordIsEmpty = state.selectedWord.isEmpty
    self.words = state.playedWords
  }

  init(replayState state: ReplayState) {
    self.isTurnBasedGame = state.localPlayerIndex != nil
    self.selectedWordIsEmpty = state.selectedWord.isEmpty
    self.words = state.moves.playedWords(
      cubes: state.cubes,
      localPlayerIndex: state.localPlayerIndex
    )
  }
}

public struct WordListView: View {
  @Environment(\.adaptiveSize) var adaptiveSize
  @Environment(\.deviceState) var deviceState

  let isAnimationReduced: Bool
  let isLeftToRight: Bool
  let store: Store<WordListState, Never>
  @ObservedObject var viewStore: ViewStore<WordListState, Never>

  public init(
    isAnimationReduced: Bool = false,
    isLeftToRight: Bool = false,
    store: Store<WordListState, Never>
  ) {
    self.isAnimationReduced = isAnimationReduced
    self.isLeftToRight = isLeftToRight
    self.store = store
    self.viewStore = ViewStore(self.store)
  }

  struct SpacerId: Hashable {}

  public var body: some View {
    if self.viewStore.selectedWordIsEmpty {
      Group {
        if self.viewStore.words.isEmpty {
          Text("Tap the cube to play")
            .adaptiveFont(.matterMedium, size: 14)
        } else {
          ScrollView(.horizontal, showsIndicators: false) {
            ScrollViewReader { reader in
              HStack(spacing: 10) {
                ForEach(
                  self.isLeftToRight ? self.viewStore.words : self.viewStore.words.reversed(),
                  id: \.word
                ) { word in
                  ZStack(alignment: .topTrailing) {
                    HStack(alignment: .top, spacing: 0) {
                      Text(word.word.capitalized)
                        .adaptiveFont(.matterMedium, size: 20)
                      Text("\(word.score)")
                        .adaptiveFont(.matterMedium, size: 14)
                    }
                    .adaptivePadding(EdgeInsets(top: 6, leading: 12, bottom: 8, trailing: 12))
                    .foregroundColor(Color.adaptiveWhite)
                    .background(self.colors(for: word))
                    .adaptiveCornerRadius(
                      UIRectCorner.allCorners.subtracting(
                        word.isYourWord ? .bottomLeft : .bottomRight),
                      15
                    )

                    HStack(spacing: -15) {
                      ForEach(self.reactions(for: word)) { reaction in
                        Text(reaction.rawValue)
                          .font(.system(size: 20 + self.adaptiveSize.padding))
                          .rotationEffect(.degrees(10))
                      }
                    }
                    .offset(x: 8, y: -8)
                  }
                }

                Spacer()
                  .frame(width: 0)
                  .id(SpacerId())
              }
              .onAppear {
                guard self.isLeftToRight else { return }
                reader.scrollTo(SpacerId(), anchor: self.isLeftToRight ? .trailing : .leading)
              }
              .onChange(of: self.viewStore.words) { _ in
                guard self.isLeftToRight else { return }
                withAnimation {
                  reader.scrollTo(SpacerId(), anchor: self.isLeftToRight ? .trailing : .leading)
                }
              }
              .screenEdgePadding(self.deviceState.isPad ? .leading : [])
              .adaptivePadding(self.deviceState.isPhone ? .leading : [])
              .padding(.vertical)
            }
          }
        }
      }
      .frame(height: 60, alignment: .center)
      .transition(
        isAnimationReduced
          ? .opacity
          : AnyTransition.offset(y: 50)
            .combined(with: .opacity)
      )
    }
  }

  func reactions(for playedWord: PlayedWord) -> [Move.Reaction] {
    (playedWord.reactions ?? [:])
      .sorted(by: { $0.key < $1.key })
      .map(\.value)
  }

  @ViewBuilder
  func colors(for playedWord: PlayedWord) -> some View {
    if self.viewStore.isTurnBasedGame && playedWord.isYourWord {
      LinearGradient(
        gradient: Gradient(colors: Styleguide.colors(for: playedWord.word)),
        startPoint: .bottomLeading,
        endPoint: .topTrailing
      )
    } else {
      Color.adaptiveBlack.opacity(0.9)
    }
  }
}

#if DEBUG
  import ClientModels
  import ComposableGameCenter
  import Overture

  struct WordListView_Previews: PreviewProvider {
    @ViewBuilder
    static var previews: some View {
      WordListView(
        store: .init(
          initialState: WordListState(
            isTurnBasedGame: false,
            selectedWordIsEmpty: true,
            words: [
              .init(isYourWord: true, reactions: nil, score: 1000, word: "AXIOLOGIST"),
            ]
          ),
          reducer: .empty,
          environment: ()
        )
      )
      .previewLayout(.fixed(width: 500, height: 100))
      .previewDisplayName("New game")

      WordListView(
        store: .init(
          initialState: .init(
            isTurnBasedGame: true,
            selectedWordIsEmpty: true,
            words: [
              .init(isYourWord: true, reactions: [0: .angel], score: 1000, word: "AXIOLOGIST"),
              .init(isYourWord: false, reactions: [1: .anger], score: 2000, word: "DOCUMENTERS"),
            ]
          ),
          reducer: .empty,
          environment: ()
        )
      )
      .previewLayout(.fixed(width: 500, height: 100))
      .previewDisplayName("Multiplayer game")
    }
  }
#endif
