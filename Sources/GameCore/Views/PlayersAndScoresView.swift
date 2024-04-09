import ComposableArchitecture
import ComposableGameCenter
import SwiftUI

struct PlayersAndScoresView: View {
  @Environment(\.opponentImage) var defaultOpponentImage
  @Environment(\.yourImage) var defaultYourImage
  @State var opponentImage: UIImage?
  let store: StoreOf<Game>
  @State var yourImage: UIImage?

  var body: some View {
    HStack(spacing: 0) {
      PlayerView(
        displayName: (store.you?.displayName).map { LocalizedStringKey($0) } ?? "You",
        image: self.defaultYourImage ?? self.yourImage,
        isPlayerTurn: store.isYourTurn,
        isYou: true,
        score: store.yourScore
      )

      PlayerView(
        displayName: (store.opponent?.displayName).map { LocalizedStringKey($0) }
          ?? "Your opponent",
        image: self.defaultOpponentImage ?? self.opponentImage,
        isPlayerTurn: !store.isYourTurn,
        isYou: false,
        score: store.opponentScore
      )
    }
    .onAppear {
      store.opponent?.rawValue?.loadPhoto(for: .small) { image, _ in
        self.opponentImage = image
      }
      store.you?.rawValue?.loadPhoto(for: .small) { image, _ in
        self.yourImage = image
      }
    }
    .onChange(of: store.opponent) { _, player in
      player?.rawValue?.loadPhoto(for: .small) { image, _ in
        self.opponentImage = image
      }
    }
    .onChange(of: store.you) { _, player in
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

fileprivate extension Game.State {
  var opponent: ComposableGameCenter.Player? {
    self.gameContext.turnBased?.otherParticipant?.player
  }
  var opponentScore: Int {
    self.gameContext.turnBased?.otherPlayerIndex
      .flatMap { self.turnBasedScores[$0] } ?? 0
  }
  var you: ComposableGameCenter.Player? {
    self.gameContext.turnBased?.localPlayer.player
  }
  var yourScore: Int {
    self.gameContext.turnBased?.localPlayerIndex
      .flatMap { self.turnBasedScores[$0] }
    ?? (self.gameContext.is(\.turnBased) ? 0 : self.currentScore)
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
          store: Store(
            initialState: Game.State(
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
            )
          ) {
          }
        )
        .previewLayout(.fixed(width: 320, height: 100))

        PlayersAndScoresView(
          store: Store(
            initialState: Game.State(
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
            )
          ) {
          }
        )
        .previewLayout(.fixed(width: 320, height: 100))
      }
    }
  }
#endif
