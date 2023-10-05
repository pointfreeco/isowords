import ClientModels
import ComposableArchitecture
import ComposableGameCenter
import DateHelpers
import SharedModels
import Styleguide
import SwiftUI

public struct ActiveGamesState: Equatable {
  public var savedGames: SavedGamesState
  public var turnBasedMatches: [ActiveTurnBasedMatch]

  public init(
    savedGames: SavedGamesState = .init(),
    turnBasedMatches: [ActiveTurnBasedMatch] = []
  ) {
    self.savedGames = savedGames
    self.turnBasedMatches = turnBasedMatches
  }

  public var isEmpty: Bool {
    self.savedGames.dailyChallengeUnlimited == nil
      && self.savedGames.unlimited == nil
      && self.turnBasedMatches.isEmpty
  }
}

public enum ActiveGamesAction: Equatable {
  case dailyChallengeTapped
  case soloTapped
  case turnBasedGameMenuItemTapped(TurnBasedMenuAction)
  case turnBasedGameTapped(ComposableGameCenter.TurnBasedMatch.Id)

  public enum TurnBasedMenuAction: Equatable {
    case deleteMatch(ComposableGameCenter.TurnBasedMatch.Id)
    case rematch(ComposableGameCenter.TurnBasedMatch.Id)
    case sendReminder(ComposableGameCenter.TurnBasedMatch.Id, otherPlayerIndex: Move.PlayerIndex)
  }
}

public struct ActiveGamesView: View {
  public static let height: CGFloat = 205

  @Environment(\.colorScheme) var colorScheme
  @Environment(\.date) var date
  let showMenuItems: Bool
  let store: Store<ActiveGamesState, ActiveGamesAction>
  @ObservedObject var viewStore: ViewStore<ActiveGamesState, ActiveGamesAction>

  public init(
    store: Store<ActiveGamesState, ActiveGamesAction>,
    showMenuItems: Bool
  ) {
    self.showMenuItems = showMenuItems
    self.store = store
    self.viewStore = ViewStore(self.store, observe: { $0 }, removeDuplicates: ==)
  }

  public var body: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 20) {
        if self.viewStore.savedGames.dailyChallengeUnlimited != nil {
          ActiveGameCard(
            button: .init(
              icon: .init(systemName: "arrow.right"),
              isActive: true,
              title: Text("Resume")
            ),
            message: Text(timeDescriptionUntilTomorrow(now: self.date()))
              .fontWeight(.medium)
              + Text("\nleft to play!")
              .foregroundColor(self.color.opacity(0.4)),
            tapAction: { self.viewStore.send(.dailyChallengeTapped, animation: .default) },
            title: Text("Daily challenge")
          )
        }

        if let inProgressGame = self.viewStore.savedGames.unlimited {
          ActiveGameCard(
            button: .init(
              icon: .init(systemName: "arrow.right"),
              isActive: true,
              title: Text("Resume")
            ),
            message: soloMessage(inProgressGame: inProgressGame),
            tapAction: { self.viewStore.send(.soloTapped, animation: .default) },
            title: Text("Solo")
          )
        }

        ForEach(self.viewStore.turnBasedMatches) { match in
          let sendReminderAction =
            !match.isYourTurn && match.isStale
            ? match.theirIndex.map { otherPlayerIndex in
              ActiveGamesAction.turnBasedGameMenuItemTapped(
                .sendReminder(match.id, otherPlayerIndex: otherPlayerIndex)
              )
            }
            : nil

          ActiveGameCard(
            button: turnBasedButton(match: match),
            message: turnBasedMessage(match: match),
            tapAction: { self.viewStore.send(.turnBasedGameTapped(match.id), animation: .default) },
            buttonAction: self.showMenuItems
              ? sendReminderAction.map { action in { self.viewStore.send(action) } }
              : nil,
            title: Text("vs \(match.theirName ?? "your opponent")")
          )
          .contextMenu(
            self.showMenuItems
              ? ContextMenu {
                if match.status == .open, !match.isYourTurn,
                  let sendReminderAction = sendReminderAction
                {
                  Button {
                    self.viewStore.send(sendReminderAction)
                  } label: {
                    Label("Send Reminder", systemImage: "clock")
                  }
                }
                Button {
                  self.viewStore.send(.turnBasedGameMenuItemTapped(.deleteMatch(match.id)))
                } label: {
                  Label("Delete Match", systemImage: "trash")
                    .foregroundColor(.red)
                }
              }
              : nil
          )
        }
      }
      .screenEdgePadding(.horizontal)
    }
  }

  func turnBasedButton(match: ActiveTurnBasedMatch) -> ActiveGameCardButton {
    if match.isYourTurn {
      return .init(
        icon: .init(systemName: "arrow.right"),
        isActive: true,
        title: Text("Your turn!")
      )
    } else {
      return .init(
        icon: match.isStale ? .init(systemName: "hand.point.right.fill") : nil,
        isActive: match.isStale,
        shouldAnimate: true,
        title: Text(match.isStale ? "Poke" : "Their turn")
      )
    }
  }

  @ViewBuilder
  func turnBasedMessage(match: ActiveTurnBasedMatch) -> some View {
    if match.isStale && !match.isYourTurn {
      Text("they haven’t played in awhile")
        .foregroundColor(self.color.opacity(0.4))
    } else if let playedWord = match.playedWord {
      Text(playedWord.isYourWord ? "you played " : "they played ")
        .foregroundColor(self.color.opacity(0.4))
        + self.text(for: playedWord)
    } else if match.isYourTurn {
      Text("you haven’t played a word yet!")
    } else {
      Text("waiting for them to play")
    }
  }

  func soloMessage(inProgressGame: InProgressGame) -> Text {
    if let lastPlayedWord = inProgressGame.lastPlayedWord {
      return Text("your last word was ")
        .foregroundColor(self.color.opacity(0.4))
        + self.text(for: lastPlayedWord)
    } else {
      return Text("you haven’t played a word yet!")
    }
  }

  var color: Color {
    self.colorScheme == .light ? .isowordsOrange : .isowordsBlack
  }

  func text(for playedWord: PlayedWord) -> Text {
    Text(playedWord.word.lowercased()).fontWeight(.medium)
      + Text("\(playedWord.score)")
      .baselineOffset(6)
      .font(.custom(.matterMedium, size: 16))
      + Text((playedWord.orderedReactions?.first).map { " \($0.rawValue)" } ?? "")
  }
}

extension InProgressGame {
  fileprivate var lastPlayedWord: PlayedWord? {
    self.moves
      .last(where: { $0.type.playedWord != nil })
      .flatMap { move -> PlayedWord? in
        guard case let .playedWord(indices) = move.type
        else { return nil }

        return PlayedWord(
          isYourWord: false,
          reactions: move.reactions,
          score: move.score,
          word: self.cubes.string(from: indices))
      }
  }
}

private func activeTurnBasedGameView(
  match: ActiveTurnBasedMatch
) -> some View {
  let title: LocalizedStringKey
  let subtitle: ActiveTurnBasedGameSubtitleView?
  let footer: LocalizedStringKey
  let isYourTurn: Bool

  if let playedWord = match.playedWord {
    subtitle = ActiveTurnBasedGameSubtitleView(
      reaction: playedWord.orderedReactions?.first,
      score: playedWord.score,
      word: playedWord.word.lowercased()
    )
    title = "\(playedWord.isYourWord ? "You" : match.theirName ?? "Your opponent") played"
    footer =
      match.isYourTurn
      ? "Your turn!"
      : "\(match.theirName.map { "\($0)’s" } ?? "Their") turn"
    isYourTurn = match.isYourTurn
  } else {
    subtitle = nil
    title =
      match.isYourTurn
      ? "You started a game"
      : "\(match.theirName ?? "Your opponent") started a game"
    footer =
      match.isYourTurn
      ? "Your turn!"
      : "\(match.theirName.map { "\($0)’s" } ?? "Their") turn"
    isYourTurn = match.isYourTurn
  }

  return ActiveGameView(
    isYourTurn: isYourTurn,
    title: title,
    subtitle: subtitle,
    footer: footer
  )
}

struct ActiveTurnBasedGameSubtitleView: View {
  let reaction: Move.Reaction?
  let score: Int
  let word: String

  var body: some View {
    HStack(alignment: .top, spacing: 2) {
      Text(self.word)
      Text("\(self.score)")
        .adaptiveFont(.matterMedium, size: 12)
      self.reaction.map { Text($0.rawValue) }
    }
  }
}

struct ActiveGameView<Subtitle: View>: View {
  var isYourTurn: Bool = true
  let title: LocalizedStringKey
  let subtitle: Subtitle?
  let footer: LocalizedStringKey

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(self.title)
        .frame(maxWidth: .infinity, alignment: .topLeading)

      self.subtitle

      Spacer()

      Text(self.footer)
        .adaptiveFont(.matterMedium, size: 14)
    }
    .padding()
    .frame(width: 180, height: ActiveGamesView.height)
    .opacity(self.isYourTurn ? 1 : 0.5)
    // NB: This is a hack to force re-renders of this view because sometimes SwiftUI doesn't
    //     finish updating the opacity while animating.
    .id(UUID())
  }
}

extension ActiveGameView where Subtitle == Text {
  init(
    isYourTurn: Bool,
    title: LocalizedStringKey,
    subtitle: LocalizedStringKey,
    footer: LocalizedStringKey
  ) {
    self.isYourTurn = isYourTurn
    self.title = title
    self.subtitle = Text(subtitle)
    self.footer = footer
  }
}

struct ActiveGameButtonStyle: ButtonStyle {
  let backgroundColor: Color
  let foregroundColor: Color

  init(
    backgroundColor: Color,
    foregroundColor: Color
  ) {
    self.backgroundColor = backgroundColor
    self.foregroundColor = foregroundColor
  }

  func makeBody(configuration: Configuration) -> some View {
    return configuration.label
      .foregroundColor(
        self.foregroundColor
          .opacity(configuration.isPressed ? 0.9 : 1)
      )
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .adaptiveFont(.matterMedium, size: 20)
      .background(
        RoundedRectangle(cornerRadius: 13)
          .fill(
            self.backgroundColor
              .opacity(configuration.isPressed ? 0.5 : 1)
          )
      )
      .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
  }
}

private let relativeDateFormatter = RelativeDateTimeFormatter()

#if DEBUG
  import Overture
  import SwiftUIHelpers

  struct ActiveGamesView_Previews: PreviewProvider {
    static var previews: some View {
      Preview {
        ScrollView {
          ActiveGamesView(
            store: Store(
              initialState: ActiveGamesState(
                savedGames: SavedGamesState(
                  dailyChallengeUnlimited: update(.mock) {
                    $0?.moves = [.highScoringMove]
                    $0?.gameContext = .dailyChallenge(.init(rawValue: .dailyChallengeId))
                  },
                  unlimited: update(.mock) {
                    $0?.moves = [.highScoringMove]
                    $0?.gameStartTime = Date().addingTimeInterval(-60 * 60 * 7)
                  }
                ),
                turnBasedMatches: []
              )
            ) {
            },
            showMenuItems: true
          )
          ActiveGamesView(
            store: Store(
              initialState: ActiveGamesState(
                savedGames: .init(),
                turnBasedMatches: [
                  .init(
                    id: "1",
                    isYourTurn: true,
                    lastPlayedAt: .mock,
                    now: .mock,
                    playedWord: PlayedWord(
                      isYourWord: false,
                      reactions: [0: .angel],
                      score: 120,
                      word: "HELLO"
                    ),
                    status: .open,
                    theirIndex: 1,
                    theirName: "Blob"
                  ),
                  .init(
                    id: "2",
                    isYourTurn: false,
                    lastPlayedAt: .mock,
                    now: .mock,
                    playedWord: PlayedWord(
                      isYourWord: true,
                      reactions: [0: .angel],
                      score: 420,
                      word: "GOODBYE"
                    ),
                    status: .open,
                    theirIndex: 0,
                    theirName: "Blob"
                  ),
                  .init(
                    id: "3",
                    isYourTurn: false,
                    lastPlayedAt: .mock,
                    now: .mock,
                    playedWord: nil,
                    status: .open,
                    theirIndex: 0,
                    theirName: "Blob"
                  ),
                ]
              )
            ) {
            },
            showMenuItems: true
          )
        }
      }
    }
  }
#endif
