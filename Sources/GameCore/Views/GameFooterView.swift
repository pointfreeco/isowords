import ComposableArchitecture
import SharedModels
import Styleguide
import SwiftUI

public struct GameFooterView: View {
  let isAnimationReduced: Bool
  let isLeftToRight: Bool
  let store: Store<GameState, GameAction>
  @ObservedObject var viewStore: ViewStore<ViewState, GameAction>

  struct ViewState: Equatable {
    let selectedWordString: String

    init(state: GameState) {
      self.selectedWordString = state.selectedWordString
    }
  }

  public init(
    isAnimationReduced: Bool,
    isLeftToRight: Bool = false,
    store: Store<GameState, GameAction>
  ) {
    self.isAnimationReduced = isAnimationReduced
    self.isLeftToRight = isLeftToRight
    self.store = store
    self.viewStore = ViewStore(self.store.scope(state: ViewState.init(state:)))
  }

  public var body: some View {
    if self.viewStore.selectedWordString.isEmpty {
      WordListView(
        isLeftToRight: self.isLeftToRight,
        store: self.store
      )
      .transition(
        isAnimationReduced
          ? .opacity
          : AnyTransition.offset(y: 50)
          .combined(with: .opacity)
      )
    }
  }
}

public struct WordListView: View {
  @Environment(\.adaptiveSize) var adaptiveSize
  @Environment(\.deviceState) var deviceState

  struct ViewState: Equatable {
    let isTurnBasedGame: Bool
    let isYourTurn: Bool
    let words: [PlayedWord]
  }

  let isLeftToRight: Bool
  let store: Store<GameState, GameAction>
  @ObservedObject var viewStore: ViewStore<ViewState, GameAction>

  public init(
    isLeftToRight: Bool = false,
    store: Store<GameState, GameAction>
  ) {
    self.isLeftToRight = isLeftToRight
    self.store = store
    self.viewStore = ViewStore(self.store.scope(state: ViewState.init(state:)))
  }

  struct SpacerId: Hashable {}

  public var body: some View {
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

extension WordListView.ViewState {
  init(state: GameState) {
    self.isTurnBasedGame = state.turnBasedContext != nil
    self.isYourTurn = state.isYourTurn
    self.words = state.playedWords
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
          initialState: .init(inProgressGame: .mock),
          reducer: .empty,
          environment: ()
        )
      )
      .previewLayout(.fixed(width: 500, height: 100))
      .previewDisplayName("New game")

      WordListView(
        store: .init(
          initialState: .init(
            gameCurrentTime: Date(),
            localPlayer: .authenticated,
            turnBasedMatch: update(.mock) {
              $0.currentParticipant = .local
              $0.participants = [.local, .remote]
            },
            turnBasedMatchData: .init(
              cubes: .mock,
              gameMode: .unlimited,
              language: .en,
              metadata: .init(),
              moves: [
                .init(
                  playedAt: Date(),
                  playerIndex: 0,
                  reactions: [1: .smilingDevil],
                  score: 36,
                  type: .playedWord(
                    [
                      .init(index: .init(x: .two, y: .two, z: .two), side: .top),
                      .init(index: .init(x: .two, y: .two, z: .two), side: .left),
                      .init(index: .init(x: .two, y: .two, z: .two), side: .right),
                    ]
                  )
                ),
                .init(
                  playedAt: Date(),
                  playerIndex: 1,
                  reactions: nil,
                  score: 36,
                  type: .playedWord(
                    [
                      .init(index: .init(x: .two, y: .two, z: .two), side: .right),
                      .init(index: .init(x: .two, y: .two, z: .two), side: .left),
                      .init(index: .init(x: .two, y: .two, z: .two), side: .top),
                    ]
                  )
                ),
              ]
            )
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
