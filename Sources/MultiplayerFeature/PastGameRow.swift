import ComposableArchitecture
import ComposableGameCenter
import SwiftUI
import Tagged

public struct PastGame: ReducerProtocol {
  public struct State: Equatable, Identifiable {
    @PresentationState public var alert: AlertState<Action.Alert>?
    public var challengeeDisplayName: String
    public var challengerDisplayName: String
    public var challengeeScore: Int
    public var challengerScore: Int
    public var endDate: Date
    public var isRematchRequestInFlight = false
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

  public enum Action: Equatable {
    case alert(PresentationAction<Alert>)
    case delegate(DelegateAction)
    case matchResponse(TaskResult<TurnBasedMatch>)
    case rematchButtonTapped
    case rematchResponse(TaskResult<TurnBasedMatch>)
    case tappedRow

    public enum Alert: Equatable {
    }
  }

  public enum DelegateAction: Equatable {
    case openMatch(TurnBasedMatch)
  }

  @Dependency(\.gameCenter) var gameCenter

  public var body: some ReducerProtocolOf<Self> {
    Reduce(self.core)
      .ifLet(\.$alert, action: /Action.alert)
  }

  public func core(into state: inout State, action: Action) -> EffectTask<Action> {
    switch action {
    case .alert:
      return .none

    case .delegate:
      return .none

    case .matchResponse(.failure):
      return .none

    case let .matchResponse(.success(match)):
      return .send(.delegate(.openMatch(match))).animation()

    case let .rematchResponse(.success(match)):
      state.isRematchRequestInFlight = false
      return .send(.delegate(.openMatch(match))).animation()

    case .rematchResponse(.failure):
      state.isRematchRequestInFlight = false
      state.alert = AlertState {
        TextState("Error")
      } actions: {
        ButtonState { TextState("OK") }
      } message: {
        TextState("We couldn’t start the rematch. Try again later.")
      }
      return .none

    case .rematchButtonTapped:
      state.isRematchRequestInFlight = true
      return .run { [matchId = state.matchId] send in
        await send(
          .rematchResponse(
            TaskResult { try await self.gameCenter.turnBasedMatch.rematch(matchId) }
          )
        )
      }

    case .tappedRow:
      return .run { [matchId = state.matchId] send in
        await send(
          .matchResponse(
            TaskResult { try await self.gameCenter.turnBasedMatch.load(matchId) }
          )
        )
      }
    }
  }
}

struct PastGameRow: View {
  @Environment(\.colorScheme) var colorScheme
  let store: StoreOf<PastGame>
  @ObservedObject var viewStore: ViewStoreOf<PastGame>

  init(store: StoreOf<PastGame>) {
    self.store = store
    self.viewStore = ViewStore(self.store, observe: { $0 })
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
    .alert(store: self.store.scope(state: \.$alert, action: PastGame.Action.alert))
  }

  func rematchButton(matchId: TurnBasedMatch.Id) -> some View {
    Button(action: { self.viewStore.send(.rematchButtonTapped, animation: .default) }) {
      HStack(spacing: .grid(1)) {
        if self.viewStore.isRematchRequestInFlight {
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

extension PastGame.State {
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
