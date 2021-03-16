import ClientModels
import Combine
import ComposableArchitecture
import ComposableGameCenter
import Styleguide
import SwiftUI

public struct PastGameState: Equatable, Identifiable {
  public var alert: AlertState<PastGameAction>?
  public var challengeeDisplayName: String
  public var challengerDisplayName: String
  public var challengeeScore: Int
  public var challengerScore: Int
  public var endDate: Date
  public var isLoadingRematch = false
  public var matchId: TurnBasedMatch.Id
  public var opponentDisplayName: String

  public var id: TurnBasedMatch.Id {
    self.matchId
  }

  enum Outcome: Equatable {
    case challengee
    case challenger
    case tied
  }

  var outcome: Outcome {
    self.challengeeScore < self.challengerScore
      ? .challenger
      : self.challengeeScore > self.challengerScore
        ? .challengee
        : .tied
  }
}

public enum PastGameAction: Equatable {
  case delegate(DelegateAction)
  case dismissAlert
  case matchResponse(Result<TurnBasedMatch, NSError>)
  case rematchButtonTapped
  case rematchResponse(Result<TurnBasedMatch, NSError>)
  case tappedRow

  public enum DelegateAction: Equatable {
    case openMatch(TurnBasedMatch)
  }
}

struct PastGameEnvironment {
  var gameCenter: GameCenterClient
  var mainQueue: AnySchedulerOf<DispatchQueue>
}

let pastGameReducer = Reducer<PastGameState, PastGameAction, PastGameEnvironment> {
  state, action, environment in
  switch action {
  case .delegate:
    return .none

  case .dismissAlert:
    state.alert = nil
    return .none

  case .matchResponse(.failure):
    return .none

  case let .matchResponse(.success(match)):
    return Effect(value: .delegate(.openMatch(match)))
      .receive(on: ImmediateScheduler.shared.animation())
      .eraseToEffect()

  case let .rematchResponse(.success(match)):
    state.isLoadingRematch = false
    return Effect(value: .delegate(.openMatch(match)))
      .receive(on: ImmediateScheduler.shared.animation())
      .eraseToEffect()

  case .rematchResponse(.failure):
    state.isLoadingRematch = false
    state.alert = .init(
      title: TextState("Error"),
      message: TextState("We couldn’t start the rematch. Try again later."),
      dismissButton: .default(TextState("Ok"), send: .dismissAlert),
      onDismiss: .dismissAlert
    )
    return .none

  case .rematchButtonTapped:
    state.isLoadingRematch = true
    return environment.gameCenter.turnBasedMatch.rematch(state.matchId)
      .receive(on: environment.mainQueue)
      .mapError { $0 as NSError }
      .catchToEffect()
      .map(PastGameAction.rematchResponse)

  case .tappedRow:
    return environment.gameCenter.turnBasedMatch.load(state.matchId)
      .receive(on: environment.mainQueue)
      .mapError { $0 as NSError }
      .catchToEffect()
      .map(PastGameAction.matchResponse)
  }
}

struct PastGameRow: View {
  @Environment(\.colorScheme) var colorScheme
  let store: Store<PastGameState, PastGameAction>
  @ObservedObject var viewStore: ViewStore<PastGameState, PastGameAction>

  init(store: Store<PastGameState, PastGameAction>) {
    self.store = store
    self.viewStore = ViewStore(self.store)
  }

  var body: some View {
    ZStack(alignment: .bottomLeading) {
      Button(action: { self.viewStore.send(.tappedRow, animation: .default) }) {
        VStack(alignment: .leading, spacing: .grid(6)) {
          HStack(spacing: .grid(1)) {
            Text("\(self.viewStore.endDate, formatter: dateFormatter)")

            Text("vs \(self.viewStore.opponentDisplayName)")
              .opacity(0.5)
              .lineLimit(1)
              .truncationMode(.tail)
          }
          .adaptiveFont(.matterMedium, size: 20)

          VStack(alignment: .leading, spacing: .grid(1)) {
            HStack {
              Text(self.viewStore.challengerDisplayName)
                .adaptiveFont(.matterMedium, size: 16)
              if self.viewStore.outcome != .challengee {
                Image(systemName: "checkmark.circle.fill")
                  .font(.system(size: 18))
              }
              Spacer()
              Text("\(self.viewStore.challengerScore)")
                .adaptiveFont(.matterMedium, size: 16) { $0.monospacedDigit() }
            }
            HStack(spacing: .grid(1)) {
              Text(self.viewStore.challengeeDisplayName)
                .adaptiveFont(.matterMedium, size: 16)
              if self.viewStore.outcome != .challenger {
                Image(systemName: "checkmark.circle.fill")
                  .font(.system(size: 18))
              }
              Spacer()
              Text("\(self.viewStore.challengeeScore)")
                .adaptiveFont(.matterMedium, size: 16) { $0.monospacedDigit() }
            }
          }

          self.rematchButton(matchId: self.viewStore.matchId)
            .hidden()
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      self.rematchButton(matchId: self.viewStore.matchId)
    }
    .alert(self.store.scope(state: \.alert))
  }

  func rematchButton(matchId: TurnBasedMatch.Id) -> some View {
    Button(action: { self.viewStore.send(.rematchButtonTapped, animation: .default) }) {
      HStack(spacing: .grid(1)) {
        if self.viewStore.isLoadingRematch {
          ProgressView()
            .progressViewStyle(
              CircularProgressViewStyle(
                tint: self.colorScheme == .light ? .multiplayer : .isowordsBlack
              )
            )
        }

        Text("Rematch")
          .adaptiveFont(.matterMedium, size: 14)
          .foregroundColor(self.colorScheme == .light ? .multiplayer : .isowordsBlack)
      }
      .padding([.horizontal])
      .padding([.vertical], .grid(2))
    }
    .background(self.colorScheme == .light ? Color.isowordsBlack : .multiplayer)
    .continuousCornerRadius(999)
  }
}

extension PastGameState {
  init?(
    turnBasedMatch match: TurnBasedMatch,
    localPlayerId: Player.Id?
  ) {
    guard match.status == .ended
    else { return nil }

    guard let matchData = match.matchData?.turnBasedMatchData
    else { return nil }

    guard let endDate = matchData.moves.last?.playedAt
    else { return nil }

    guard
      match.participants.count == 2,
      let firstIndex = matchData.moves.first?.playerIndex?.rawValue,
      let challengerPlayer = match.participants[firstIndex].player,
      let challengeePlayer = match.participants[firstIndex == 0 ? 1 : 0].player
    else { return nil }

    guard
      let opponentIndex = match.participants
        .firstIndex(where: { $0.player?.gamePlayerId != localPlayerId })
    else { return nil }

    guard
      let opponentPlayer = match.participants[opponentIndex].player
    else { return nil }

    self.challengeeDisplayName = challengeePlayer.displayName
    self.challengeeScore = matchData.score(forPlayerIndex: 1)
    self.challengerDisplayName = challengerPlayer.displayName
    self.challengerScore = matchData.score(forPlayerIndex: 0)
    self.endDate = endDate
    self.matchId = match.matchId
    self.opponentDisplayName = opponentPlayer.displayName
  }
}

private let dateFormatter: DateFormatter = {
  var formatter = DateFormatter()
  formatter.dateStyle = .medium
  return formatter
}()
