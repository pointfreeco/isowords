import ComposableArchitecture
import ComposableGameCenter
import SwiftUI
import Tagged

@Reducer
public struct PastGame {
  @ObservableState
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

    init(
      alert: AlertState<Action.Alert>? = nil,
      challengeeDisplayName: String,
      challengerDisplayName: String,
      challengeeScore: Int,
      challengerScore: Int,
      endDate: Date,
      isRematchRequestInFlight: Bool = false,
      matchId: TurnBasedMatch.Id,
      opponentDisplayName: String
    ) {
      self.alert = alert
      self.challengeeDisplayName = challengeeDisplayName
      self.challengerDisplayName = challengerDisplayName
      self.challengeeScore = challengeeScore
      self.challengerScore = challengerScore
      self.endDate = endDate
      self.isRematchRequestInFlight = isRematchRequestInFlight
      self.matchId = matchId
      self.opponentDisplayName = opponentDisplayName
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
    case delegate(Delegate)
    case matchResponse(TaskResult<TurnBasedMatch>)
    case rematchButtonTapped
    case rematchResponse(TaskResult<TurnBasedMatch>)
    case tappedRow

    public enum Alert: Equatable {
    }

    public enum Delegate: Equatable {
      case openMatch(TurnBasedMatch)
    }
  }

  @Dependency(\.gameCenter) var gameCenter

  public var body: some ReducerOf<Self> {
    Reduce(self.core)
      .ifLet(\.$alert, action: \.alert)
  }

  public func core(into state: inout State, action: Action) -> EffectOf<Self> {
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
        ButtonState { TextState("Ok") }
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

  var body: some View {
    ZStack(alignment: .bottomLeading) {
      Button {
        self.store.send(.tappedRow, animation: .default)
      } label: {
        VStack(alignment: .leading, spacing: .grid(6)) {
          HStack(spacing: .grid(1)) {
            Text("\(self.store.endDate, formatter: dateFormatter)")

            Text("vs \(self.store.opponentDisplayName)")
              .opacity(0.5)
              .lineLimit(1)
              .truncationMode(.tail)
          }
          .adaptiveFont(.matterMedium, size: 20)

          VStack(alignment: .leading, spacing: .grid(1)) {
            HStack {
              Text(self.store.challengerDisplayName)
                .adaptiveFont(.matterMedium, size: 16)
              if self.store.outcome != .challengee {
                Image(systemName: "checkmark.circle.fill")
                  .font(.system(size: 18))
              }
              Spacer()
              Text("\(self.store.challengerScore)")
                .adaptiveFont(.matterMedium, size: 16) { $0.monospacedDigit() }
            }
            HStack(spacing: .grid(1)) {
              Text(self.store.challengeeDisplayName)
                .adaptiveFont(.matterMedium, size: 16)
              if self.store.outcome != .challenger {
                Image(systemName: "checkmark.circle.fill")
                  .font(.system(size: 18))
              }
              Spacer()
              Text("\(self.store.challengeeScore)")
                .adaptiveFont(.matterMedium, size: 16) { $0.monospacedDigit() }
            }
          }

          self.rematchButton(matchId: self.store.matchId)
            .hidden()
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      self.rematchButton(matchId: self.store.matchId)
    }
    .alert(store: self.store.scope(state: \.$alert, action: \.alert))
  }

  func rematchButton(matchId: TurnBasedMatch.Id) -> some View {
    Button {
      self.store.send(.rematchButtonTapped, animation: .default)
    } label: {
      HStack(spacing: .grid(1)) {
        if self.store.isRematchRequestInFlight {
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
      .padding(.horizontal)
      .padding(.vertical, .grid(2))
    }
    .background(self.colorScheme == .light ? Color.isowordsBlack : .multiplayer)
    .continuousCornerRadius(999)
  }
}

private let dateFormatter: DateFormatter = {
  var formatter = DateFormatter()
  formatter.dateStyle = .medium
  return formatter
}()
