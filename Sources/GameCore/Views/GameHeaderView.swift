import ClientModels
import ComposableArchitecture
import ComposableGameCenter
import PuzzleGen
import SharedModels
import SwiftUI

public struct GameHeaderState: Equatable {
  let isTurnBasedGame: Bool
  let selectedWordString: String

  let currentScore: Int
  let gameContext: GameContext
  let gameMode: GameMode
  let secondsRemaining: Int
  let selectedWordHasAlreadyBeenPlayed: Bool
  let selectedWordIsValid: Bool
  let selectedWordScore: Int

  let isYourTurn: Bool
  let opponent: ComposableGameCenter.Player?
  let opponentScore: Int
  let you: ComposableGameCenter.Player?
  let yourScore: Int

  init(gameState state: GameState) {
    self.isTurnBasedGame = state.turnBasedContext != nil
    self.selectedWordString = state.selectedWordString

    self.currentScore = state.currentScore
    self.gameContext = state.gameContext
    self.gameMode = state.gameMode
    self.secondsRemaining = max(0, state.gameMode.seconds - state.secondsPlayed)
    self.selectedWordHasAlreadyBeenPlayed = state.selectedWordHasAlreadyBeenPlayed
    self.selectedWordIsValid = state.selectedWordIsValid
    self.selectedWordScore = state.selectedWordScore

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

  init(replayState state: ReplayState) {
    let turnBasedContext = (/GameContext.turnBased).extract(from: state.gameContext)
    self.isTurnBasedGame = turnBasedContext != nil
    self.selectedWordString = state.selectedWordString
    self.currentScore = state.moves.reduce(into: 0) { $0 += $1.score }
    self.gameContext = state.gameContext
    self.gameMode = .unlimited
    self.secondsRemaining = 0
    self.selectedWordHasAlreadyBeenPlayed = false
    self.selectedWordIsValid = state.selectedWordIsValid
    self.selectedWordScore = score(state.selectedWordString)
    self.isYourTurn = state.isYourTurn
    self.opponent = turnBasedContext?.otherPlayer
    self.opponentScore = state.moves
      .reduce(into: 0) { $0 += $1.playerIndex == turnBasedContext?.localPlayerIndex ? 0 : $1.score }
    self.you = turnBasedContext?.localPlayer.player
    self.yourScore = state.moves
      .reduce(into: 0) { $0 += $1.playerIndex == turnBasedContext?.localPlayerIndex ? $1.score : 0 }
  }
}

struct GameHeaderView: View {
  let store: Store<GameHeaderState, Never>
  @ObservedObject var viewStore: ViewStore<GameHeaderState, Never>

  public init(
    store: Store<GameHeaderState, Never>
  ) {
    self.store = store
    self.viewStore = ViewStore(self.store)
  }

  var body: some View {
    if self.viewStore.isTurnBasedGame, self.viewStore.selectedWordString.isEmpty {
      PlayersAndScoresView(
        isYourTurn: self.viewStore.isYourTurn,
        opponent: self.viewStore.opponent,
        opponentScore: self.viewStore.opponentScore,
        you: self.viewStore.you,
        yourScore: self.viewStore.yourScore
      )
        .transition(.opacity)
    } else {
      ScoreView(
        currentScore: self.viewStore.currentScore,
        gameContext: self.viewStore.gameContext,
        gameMode: self.viewStore.gameMode,
        secondsRemaining: self.viewStore.secondsRemaining,
        selectedWordHasAlreadyBeenPlayed: self.viewStore.selectedWordHasAlreadyBeenPlayed,
        selectedWordIsValid: self.viewStore.selectedWordIsValid,
        selectedWordScore: self.viewStore.selectedWordScore,
        selectedWordString: self.viewStore.selectedWordString
      )
    }
  }
}

struct ScoreView: View {
  @Environment(\.deviceState) var deviceState
  @State var isTimeAccented = false
  let currentScore: Int
  let gameContext: GameContext
  let gameMode: GameMode
  let secondsRemaining: Int
  let selectedWordHasAlreadyBeenPlayed: Bool
  let selectedWordIsValid: Bool
  let selectedWordScore: Int
  let selectedWordString: String

  var body: some View {
    HStack {
      if self.selectedWordString.isEmpty {
        if !self.gameContext.isTurnBased {
          Text("\(self.currentScore)")
        }
      } else {
        Text(self.selectedWordString)
          .overlay(
            Text(
              self.selectedWordIsValid
                ? "\(self.selectedWordScore)"
                : self.selectedWordHasAlreadyBeenPlayed
                  ? "(used)"
                  : ""
            )
            .adaptiveFont(.matterMedium, size: self.deviceState.isPad ? 18 : 14)
            .alignmentGuide(.top) { _ in 0 }
            .alignmentGuide(.trailing) { _ in 0 },
            alignment: .topTrailing
          )
          .opacity(self.selectedWordIsValid ? 1 : 0.5)
          .allowsTightening(true)
          .minimumScaleFactor(0.2)
          .lineLimit(1)
          .transition(.opacity)
          .animation(nil, value: self.selectedWordString)
      }

      Spacer()

      if !self.gameContext.isTurnBased {
        Text(
          displayTime(
            gameMode: self.gameMode,
            secondsRemaining: self.secondsRemaining
          )
        )
        .foregroundColor(.white)
        .colorMultiply(self.isTimeAccented ? .red : .adaptiveBlack)
        .scaleEffect(self.isTimeAccented ? 1.5 : 1)
        .onChange(of: self.secondsRemaining) { secondsRemaining in
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
