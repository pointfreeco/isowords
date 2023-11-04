import ClientModels
import ComposableArchitecture
import SharedModels
import SwiftUI

struct GameHeaderView: View {
  let store: StoreOf<Game>

  var body: some View {
    if self.store.gameContext.is(\.turnBased), self.store.selectedWordString.isEmpty {
      PlayersAndScoresView(store: self.store)
        .transition(.opacity)
    } else {
      ScoreView(store: self.store)
    }
  }
}

struct ScoreView: View {
  @Environment(\.deviceState) var deviceState
  let store: StoreOf<Game>

  @State var isTimeAccented = false

  var body: some View {
    HStack {
      if self.store.selectedWordString.isEmpty {
        if !self.store.gameContext.is(\.turnBased) {
          Text("\(self.store.currentScore)")
        }
      } else {
        Text(self.store.selectedWordString)
          .overlay(
            Text(
              self.store.selectedWordIsValid
                ? "\(self.store.selectedWordScore)"
                : self.store.selectedWordHasAlreadyBeenPlayed
                  ? "(used)"
                  : ""
            )
            .adaptiveFont(.matterMedium, size: self.deviceState.isPad ? 18 : 14)
            .alignmentGuide(.top) { _ in 0 }
            .alignmentGuide(.trailing) { _ in 0 },
            alignment: .topTrailing
          )
          .opacity(self.store.selectedWordIsValid ? 1 : 0.5)
          .allowsTightening(true)
          .minimumScaleFactor(0.2)
          .lineLimit(1)
          .transition(.opacity)
          .animation(nil, value: self.store.selectedWordString)
      }

      Spacer()

      if !self.store.gameContext.is(\.turnBased) {
        let secondsRemaining = max(0, self.store.gameMode.seconds - self.store.secondsPlayed)
        Text(
          displayTime(
            gameMode: self.store.gameMode,
            secondsRemaining: secondsRemaining
          )
        )
        .foregroundColor(.white)
        .colorMultiply(self.isTimeAccented ? .red : .adaptiveBlack)
        .scaleEffect(self.isTimeAccented ? 1.5 : 1)
        .onChange(of: secondsRemaining) { _, secondsRemaining in
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
