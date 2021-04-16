import ComposableArchitecture
import ComposableGameCenter
import SharedSwiftUIEnvironment
import SwiftUI
import SwiftUIHelpers

struct PlayersAndScoresView: View {
  @Environment(\.opponentImage) var defaultOpponentImage
  @Environment(\.yourImage) var defaultYourImage
  @State var opponentImage: UIImage?
  @State var yourImage: UIImage?
  let isYourTurn: Bool
  let opponent: ComposableGameCenter.Player?
  let opponentScore: Int
  let you: ComposableGameCenter.Player?
  let yourScore: Int

  var body: some View {
    HStack(spacing: 0) {
      PlayerView(
        displayName: (self.you?.displayName).map { LocalizedStringKey($0) } ?? "You",
        image: self.defaultYourImage ?? self.yourImage,
        isPlayerTurn: self.isYourTurn,
        isYou: true,
        score: self.yourScore
      )

      PlayerView(
        displayName: (self.opponent?.displayName).map { LocalizedStringKey($0) }
          ?? "Your opponent",
        image: self.defaultOpponentImage ?? self.opponentImage,
        isPlayerTurn: !self.isYourTurn,
        isYou: false,
        score: self.opponentScore
      )
    }
    .onAppear {
      self.opponent?.rawValue?.loadPhoto(for: .small) { image, _ in
        self.opponentImage = image
      }
      self.you?.rawValue?.loadPhoto(for: .small) { image, _ in
        self.yourImage = image
      }
    }
    .onChange(of: self.opponent) { player in
      player?.rawValue?.loadPhoto(for: .small) { image, _ in
        self.opponentImage = image
      }
    }
    .onChange(of: self.you) { player in
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
          isYourTurn: false,
          opponent: Player.remote,
          opponentScore: 1000,
          you: .local,
          yourScore: 2000
        )
        .previewLayout(.fixed(width: 320, height: 100))

        PlayersAndScoresView(
          isYourTurn: true,
          opponent: .init(
            alias: "Incredible Guide of Huge Abbey",
            displayName: "Incredible Guide of Huge Abbey",
            gamePlayerId: "1"
          ),
          opponentScore: 2000,
          you: .local,
          yourScore: 2000
        )
        .previewLayout(.fixed(width: 320, height: 100))
      }
    }
  }
#endif
