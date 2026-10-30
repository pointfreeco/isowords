import ComposableArchitecture
import ComposableGameCenter
import Dependencies
import SwiftUI
import Tagged

@Feature
public struct PastGame {
  public struct State: Identifiable {
    public var challengeeDisplayName: String
    public var challengerDisplayName: String
    public var challengeeScore: Int
    public var challengerScore: Int
    public var endDate: Date
    public var isRematchErrorAlertPresented = false
    public var isRematchRequestInFlight = false
    public var matchId: TurnBasedMatch.Id
    public var opponentDisplayName: String

    public var id: TurnBasedMatch.Id {
      matchId
    }

    enum Outcome: Equatable {
      case challengee
      case challenger
      case tied
    }

    var outcome: Outcome {
      challengeeScore < challengerScore
        ? .challenger
        : challengeeScore > challengerScore
          ? .challengee
          : .tied
    }

    init(
      challengeeDisplayName: String,
      challengerDisplayName: String,
      challengeeScore: Int,
      challengerScore: Int,
      endDate: Date,
      isRematchErrorAlertPresented: Bool = false,
      isRematchRequestInFlight: Bool = false,
      matchId: TurnBasedMatch.Id,
      opponentDisplayName: String
    ) {
      self.challengeeDisplayName = challengeeDisplayName
      self.challengerDisplayName = challengerDisplayName
      self.challengeeScore = challengeeScore
      self.challengerScore = challengerScore
      self.endDate = endDate
      self.isRematchErrorAlertPresented = isRematchErrorAlertPresented
      self.isRematchRequestInFlight = isRematchRequestInFlight
      self.matchId = matchId
      self.opponentDisplayName = opponentDisplayName
    }
  }

  public enum Action {
    case rematchButtonTapped
    case tappedRow
  }

  public enum OpenMatch: FeatureEventKey {
    public typealias Value = TurnBasedMatch
  }

  @Dependency(\.gameCenter) var gameCenter

  public var body: some Feature {
    Update { state, action in
      switch action {
      case .rematchButtonTapped:
        state.isRematchRequestInFlight = true
        store.addTask { [matchId = state.matchId] in
          do {
            let match = try await gameCenter.turnBasedMatch.rematch(matchId)
            try store.modify { $0.isRematchRequestInFlight = false }
            try await openMatch(match)
          } catch is CancellationError {
          } catch {
            try store.modify {
              $0.isRematchRequestInFlight = false
              $0.isRematchErrorAlertPresented = true
            }
          }
        }

      case .tappedRow:
        store.addTask { [matchId = state.matchId] in
          guard let match = try? await gameCenter.turnBasedMatch.load(matchId)
          else { return }
          try await openMatch(match)
        }
      }
    }
  }

  private func openMatch(_ match: TurnBasedMatch) async throws {
    try withAnimation {
      _ = try store.post(key: OpenMatch.self, value: match)
    }
  }
}

struct PastGameRow: View {
  @Environment(\.colorScheme) var colorScheme
  @Bindable var store: StoreOf<PastGame>

  var body: some View {
    ZStack(alignment: .bottomLeading) {
      Button {
        withAnimation { _ = store.send(.tappedRow) }
      } label: {
        VStack(alignment: .leading, spacing: .grid(6)) {
          HStack(spacing: .grid(1)) {
            Text("\(store.endDate, formatter: dateFormatter)")

            Text("vs \(store.opponentDisplayName)")
              .opacity(0.5)
              .lineLimit(1)
              .truncationMode(.tail)
          }
          .adaptiveFont(.matterMedium, size: 20)

          VStack(alignment: .leading, spacing: .grid(1)) {
            HStack {
              Text(store.challengerDisplayName)
                .adaptiveFont(.matterMedium, size: 16)
              if store.outcome != .challengee {
                Image(systemName: "checkmark.circle.fill")
                  .font(.system(size: 18))
              }
              Spacer()
              Text("\(store.challengerScore)")
                .adaptiveFont(.matterMedium, size: 16) { $0.monospacedDigit() }
            }
            HStack(spacing: .grid(1)) {
              Text(store.challengeeDisplayName)
                .adaptiveFont(.matterMedium, size: 16)
              if store.outcome != .challenger {
                Image(systemName: "checkmark.circle.fill")
                  .font(.system(size: 18))
              }
              Spacer()
              Text("\(store.challengeeScore)")
                .adaptiveFont(.matterMedium, size: 16) { $0.monospacedDigit() }
            }
          }

          rematchButton(matchId: store.matchId)
            .hidden()
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      rematchButton(matchId: store.matchId)
    }
    .alert("Error", isPresented: $store.isRematchErrorAlertPresented) {
      Button("Ok") {}
    } message: {
      Text("We couldn’t start the rematch. Try again later.")
    }
  }

  func rematchButton(matchId: TurnBasedMatch.Id) -> some View {
    Button {
      withAnimation { _ = store.send(.rematchButtonTapped) }
    } label: {
      HStack(spacing: .grid(1)) {
        if store.isRematchRequestInFlight {
          ProgressView()
            .progressViewStyle(
              CircularProgressViewStyle(
                tint: colorScheme == .light ? .multiplayer : .isowordsBlack
              )
            )
        }

        Text("Rematch")
          .adaptiveFont(.matterMedium, size: 14)
          .foregroundColor(colorScheme == .light ? .multiplayer : .isowordsBlack)
      }
      .padding(.horizontal)
      .padding(.vertical, .grid(2))
    }
    .background(colorScheme == .light ? Color.isowordsBlack : .multiplayer)
    .continuousCornerRadius(999)
  }
}

private let dateFormatter: DateFormatter = {
  var formatter = DateFormatter()
  formatter.dateStyle = .medium
  return formatter
}()
