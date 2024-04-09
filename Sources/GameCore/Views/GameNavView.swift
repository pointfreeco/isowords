import ComposableArchitecture
import SwiftUI

struct GameNavView: View {
  let store: StoreOf<Game>

  var body: some View {
    HStack(alignment: .center, spacing: 8) {
      Button {
        store.send(.trayButtonTapped, animation: .default)
      } label: {
        HStack {
          Text(store.displayTitle)
            .lineLimit(1)

          Spacer()

          Image(systemName: "chevron.down")
            .rotationEffect(.degrees(store.isTrayVisible ? 180 : 0))
            .opacity(store.isTrayAvailable ? 1 : 0)
        }
        .adaptiveFont(.matterMedium, size: 14)
        .foregroundColor(.adaptiveBlack)
        .adaptivePadding()
      }
      .background(
        Color.adaptiveBlack
          .opacity(0.05)
      )
      .cornerRadius(12)
      .disabled(!store.isTrayAvailable)

      Button {
        store.send(.menuButtonTapped, animation: .default)
      } label: {
        Image(systemName: "ellipsis")
          .foregroundColor(.adaptiveBlack)
          .adaptivePadding()
          .rotationEffect(.degrees(90))
      }
      .frame(maxHeight: .infinity)
      .background(
        Color.adaptiveBlack
          .opacity(0.05)
      )
      .cornerRadius(12)
    }
    .fixedSize(horizontal: false, vertical: true)
    .padding(.horizontal)
    .adaptivePadding(.vertical, 8)
  }
}

#if DEBUG
  import Overture

  struct GameNavView_Previews: PreviewProvider {
    static var previews: some View {
      VStack {
        GameNavView(
          store: Store(initialState: .init(inProgressGame: .mock)) {
          }
        )
        Spacer()
      }
    }
  }
#endif
