import ClientModels
import ComposableArchitecture
import SharedModels
import SwiftUI

struct GameHeaderView: View {
  let store: StoreOf<Game>
  @ObservedObject var viewStore: ViewStore<ViewState, Game.Action>

  struct ViewState: Equatable {
    let isTurnBasedGame: Bool
    let selectedWordString: String

    init(state: Game.State) {
      self.isTurnBasedGame = state.gameContext.is(\.turnBased)
      self.selectedWordString = state.selectedWordString
    }
  }

  public init(
    store: StoreOf<Game>
  ) {
    self.store = store
    self.viewStore = ViewStore(self.store, observe: ViewState.init)
  }

  var body: some View {
    if self.viewStore.isTurnBasedGame, self.viewStore.selectedWordString.isEmpty {
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
  @ObservedObject var viewStore: ViewStore<ViewState, Game.Action>

  @State var isTimeAccented = false

  struct ViewState: Equatable {
    let currentScore: Int
    let gameContext: GameContext
    let gameMode: GameMode
    let secondsRemaining: Int
    let selectedWordHasAlreadyBeenPlayed: Bool
    let selectedWordIsValid: Bool
    let selectedWordScore: Int
    let selectedWordString: String

    init(state: Game.State) {
      self.currentScore = state.currentScore
      self.gameContext = state.gameContext
      self.gameMode = state.gameMode
      self.secondsRemaining = max(0, state.gameMode.seconds - state.secondsPlayed)
      self.selectedWordHasAlreadyBeenPlayed = state.selectedWordHasAlreadyBeenPlayed
      self.selectedWordIsValid = state.selectedWordIsValid
      self.selectedWordScore = state.selectedWordScore
      self.selectedWordString = state.selectedWordString
    }
  }

  public init(
    store: StoreOf<Game>
  ) {
    self.store = store
    self.viewStore = ViewStore(self.store, observe: ViewState.init)
  }

  var body: some View {
    HStack {
      if self.viewStore.selectedWordString.isEmpty {
        if !self.viewStore.gameContext.is(\.turnBased) {
          Text("\(self.viewStore.currentScore)")
        }
      } else {
        Text(self.viewStore.selectedWordString)
          .overlay(
            Text(
              self.viewStore.selectedWordIsValid
                ? "\(self.viewStore.selectedWordScore)"
                : self.viewStore.selectedWordHasAlreadyBeenPlayed
                  ? "(used)"
                  : ""
            )
            .adaptiveFont(.matterMedium, size: self.deviceState.isPad ? 18 : 14)
            .alignmentGuide(.top) { _ in 0 }
            .alignmentGuide(.trailing) { _ in 0 },
            alignment: .topTrailing
          )
          .opacity(self.viewStore.selectedWordIsValid ? 1 : 0.5)
          .allowsTightening(true)
          .minimumScaleFactor(0.2)
          .lineLimit(1)
          .transition(.opacity)
          .animation(nil, value: self.viewStore.selectedWordString)
      }

      Spacer()

      if !self.viewStore.gameContext.is(\.turnBased) {
        Text(
          displayTime(
            gameMode: self.viewStore.gameMode,
            secondsRemaining: self.viewStore.secondsRemaining
          )
        )
        .foregroundColor(.white)
        .colorMultiply(self.isTimeAccented ? .red : .adaptiveBlack)
        .scaleEffect(self.isTimeAccented ? 1.5 : 1)
        .onChange(of: self.viewStore.secondsRemaining) { secondsRemaining in
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
