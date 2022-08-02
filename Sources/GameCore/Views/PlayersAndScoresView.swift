import ComposableArchitecture
import ComposableGameCenter
import SharedSwiftUIEnvironment
import SwiftUI
import SwiftUIHelpers

struct PlayersAndScoresView: View {
  @Environment(\.opponentImage) var defaultOpponentImage
  @Environment(\.yourImage) var defaultYourImage
  @State var opponentImage: UIImage?
  let store: StoreOf<Game>
  @State var yourImage: UIImage?
  @ObservedObject var viewStore: ViewStore<ViewState, Game.Action>

  struct ViewState: Equatable {
    let isYourTurn: Bool
    let opponent: ComposableGameCenter.Player?
    let opponentScore: Int
    let you: ComposableGameCenter.Player?
    let yourScore: Int

    init(state: Game.State) {
      self.isYourTurn = state.isYourTurn
      self.opponent = state.turnBasedContext?.otherParticipant?.player
      self.you = state.turnBasedContext?.localPlayer.player
      self.yourScore =
        state.turnBasedContext?.localPlayerIndex
        .flatMap { state.turnBasedScores[$0] }
        ?? (state.turnBasedContext == nil ? state.currentScore : 0)
      self.opponentScore =
        state.turnBasedContext?.otherPlayerIndex
        .flatMap { state.turnBasedScores[$0] } ?? 0
    }
  }

  public init(
    store: StoreOf<Game>
  ) {
    self.store = store
    self.viewStore = ViewStore(self.store.scope(state: ViewState.init(state:)))
  }

  var body: some View {
    HStack(spacing: 0) {
      PlayerView(
        displayName: (self.viewStore.you?.displayName).map { LocalizedStringKey($0) } ?? "You",
        image: self.defaultYourImage ?? self.yourImage,
        isPlayerTurn: self.viewStore.isYourTurn,
        isYou: true,
        score: self.viewStore.yourScore
      )

      PlayerView(
        displayName: (self.viewStore.opponent?.displayName).map { LocalizedStringKey($0) }
          ?? "Your opponent",
        image: self.defaultOpponentImage ?? self.opponentImage,
        isPlayerTurn: !self.viewStore.isYourTurn,
        isYou: false,
        score: self.viewStore.opponentScore
      )
    }
    .onAppear {
      self.viewStore.opponent?.rawValue?.loadPhoto(for: .small) { image, _ in
        self.opponentImage = image
      }
      self.viewStore.you?.rawValue?.loadPhoto(for: .small) { image, _ in
        self.yourImage = image
      }
    }
    .onChange(of: self.viewStore.opponent) { player in
      player?.rawValue?.loadPhoto(for: .small) { image, _ in
        self.opponentImage = image
      }
    }
    .onChange(of: self.viewStore.you) { player in
      player?.rawValue?.loadPhoto(for: .small) { image, _ in
        self.yourImage = image
      }
    }
  }
}

private struct PlayerView: View {
  let displayName: LocalizedStringKey
  let image: UIImage?
  let isPlayerTurn: Bool
  let isYou: Bool
  let score: Int

  var body: some View {
    HStack {
      if self.isYou {
        self.nameAndScore
        self.avatar
      } else {
        self.avatar
        self.nameAndScore
      }
    }
    .frame(minWidth: 0, maxWidth: .infinity, alignment: self.isYou ? .trailing : .leading)
    .offset(x: self.isYou ? 8 : -8)
    .applying {
      if self.isPlayerTurn {
        $0.zIndex(1)
      } else {
        $0.opacity(0.4)
      }
    }
  }

  var nameAndScore: some View {
    VStack(alignment: self.isYou ? .trailing : .leading, spacing: 0) {
      HStack(alignment: .center) {
        Text(self.displayName)
          .adaptiveFont(.matterMedium, size: 14)
          .multilineTextAlignment(.trailing)
          .lineLimit(1)
      }
      Text("\(self.score)")
        .adaptiveFont(.matterMedium, size: 16)
    }
  }

  var avatar: some View {
    ZStack(alignment: self.isYou ? .bottomLeading : .bottomTrailing) {
      Rectangle()
        .overlay(
          self.image.map {
            Image(uiImage: $0)
              .resizable()
              .scaledToFill()
              .transition(.opacity)
          }
        )
        .frame(width: 40, height: 40, alignment: .center)
        .clipShape(Circle())

      if self.isPlayerTurn {
        Circle()
          .frame(width: 10, height: 10)
          .foregroundColor(.yellow)
          .zIndex(1)
      }
    }
  }
}

#if DEBUG
  import ClientModels
  import Overture
  import SharedModels

  struct PlayersAndScoresView_Previews: PreviewProvider {
    static var previews: some View {
      Group {
        PlayersAndScoresView(
          store: .init(
            initialState: .init(
              gameCurrentTime: Date(),
              localPlayer: .authenticated,
              turnBasedMatch: update(.inProgress) {
                $0.currentParticipant = $0.participants[1]
              },
              turnBasedMatchData: .init(
                cubes: .mock,
                gameMode: .unlimited,
                language: .en,
                metadata: .init(lastOpenedAt: nil, playerIndexToId: [:]),
                moves: []
              )
            ),
            reducer: .empty,
            environment: ()
          )
        )
        .previewLayout(.fixed(width: 320, height: 100))

        PlayersAndScoresView(
          store: .init(
            initialState: .init(
              gameCurrentTime: Date(),
              localPlayer: update(.authenticated) {
                $0.displayName = "Incredible Guide of Huge Abbey"
              },
              turnBasedMatch: update(.inProgress) {
                $0.participants[0].player!.displayName = "Incredible Guide of Huge Abbey"
              },
              turnBasedMatchData: TurnBasedMatchData(
                cubes: .mock,
                gameMode: .unlimited,
                language: .en,
                metadata: .init(lastOpenedAt: nil, playerIndexToId: [:]),
                moves: [
                  .init(
                    playedAt: .mock,
                    playerIndex: 1,
                    reactions: [1: .smirk],
                    score: 666,
                    type: .playedWord(
                      [
                        .init(index: .init(x: .two, y: .two, z: .two), side: .top),
                        .init(index: .init(x: .two, y: .two, z: .two), side: .left),
                        .init(index: .init(x: .two, y: .two, z: .two), side: .right),
                      ]
                    )
                  )
                ]
              )
            ),
            reducer: .empty,
            environment: ()
          )
        )
        .previewLayout(.fixed(width: 320, height: 100))
      }
    }
  }
#endif
