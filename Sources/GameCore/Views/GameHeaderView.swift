import ClientModels
import ComposableArchitecture
import SharedModels
import SwiftUI

struct GameHeaderView: View {
  let store: StoreOf<Game>

  var body: some View {
    if store.gameContext.is(\.turnBased), store.selectedWordString.isEmpty {
      PlayersAndScoresView(store: store)
        .transition(.opacity)
    } else {
      ScoreView(store: store)
    }
  }
}

extension Game.State {
  fileprivate var secondsRemaining: Int {
    max(0, self.gameMode.seconds - self.secondsPlayed)
  }
}

struct ScoreView: View {
  @Environment(\.deviceState) var deviceState
  let store: StoreOf<Game>

  @State var isTimeAccented = false

  var body: some View {
    HStack {
      if store.selectedWordString.isEmpty {
        if !store.gameContext.is(\.turnBased) {
          Text("\(store.currentScore)")
        }
      } else {
        Text(store.selectedWordString)
          .overlay(
            Text(
              store.selectedWordIsValid
                ? "\(store.selectedWordScore)"
                : store.selectedWordHasAlreadyBeenPlayed
                  ? "(used)"
                  : ""
            )
            .adaptiveFont(.matterMedium, size: self.deviceState.isPad ? 18 : 14)
            .alignmentGuide(.top) { _ in 0 }
            .alignmentGuide(.trailing) { _ in 0 },
            alignment: .topTrailing
          )
          .opacity(store.selectedWordIsValid ? 1 : 0.5)
          .allowsTightening(true)
          .minimumScaleFactor(0.2)
          .lineLimit(1)
          .transition(.opacity)
          .animation(nil, value: store.selectedWordString)
      }

      Spacer()

      if !store.gameContext.is(\.turnBased) {
        Text(
          displayTime(
            gameMode: store.gameMode,
            secondsRemaining: store.secondsRemaining
          )
        )
        .foregroundColor(.white)
        .colorMultiply(self.isTimeAccented ? .red : .adaptiveBlack)
        .scaleEffect(self.isTimeAccented ? 1.5 : 1)
        .onChange(of: store.secondsRemaining) { _, secondsRemaining in
          guard secondsRemaining == 10 || (secondsRemaining <= 5 && secondsRemaining > 0)
          else { return }

          withAnimation(.spring()) {
            self.isTimeAccented = true
          }
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.spring()) {
              self.isTimeAccented = false
            }
          }
        }
      }
    }
    .adaptiveFont(.matterSemiBold, size: self.deviceState.isPad ? 40 : 32)
    .adaptivePadding(.horizontal)
  }
}

private func displayTime(
  gameMode: GameMode,
  secondsRemaining: Int
) -> String {
  switch gameMode {
  case .timed:
    return "\(secondsRemaining / 60):\(String(format: "%02d", secondsRemaining % 60))"
  case .unlimited:
    return "∞"
  }
}
