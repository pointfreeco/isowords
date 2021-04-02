import Combine
import ComposableArchitecture
import GameKit
import Tagged

public struct GameCenterClient {
  public var gameCenterViewController: GameCenterViewControllerClient
  public var localPlayer: LocalPlayerClient
  public var reportAchievements: ([GKAchievement]) -> Effect<Void, Error>
  public var showNotificationBanner: (NotificationBannerRequest) -> Effect<Void, Never>
  public var turnBasedMatch: TurnBasedMatchClient
  public var turnBasedMatchmakerViewController: TurnBasedMatchmakerViewControllerClient

  public struct NotificationBannerRequest: Equatable {
    public var message: String?
    public var title: String?

    public init(title: String?, message: String?) {
      self.title = title
      self.message = message
    }
  }
}

public struct GameCenterViewControllerClient {
  public var present: Effect<DelegateEvent, Never>
  public var dismiss: Effect<Never, Never>

  public enum DelegateEvent: Equatable {
    case didFinish
  }
}

public struct LocalPlayerClient {
  public var authenticate: Effect<NSError?, Never>
  public var listener: Effect<ListenerEvent, Never>
  public var localPlayer: () -> LocalPlayer
  public var presentAuthenticationViewController: Effect<Never, Never>

  public enum ListenerEvent: Equatable {
    case challenge(ChallengeEvent)
    case invite(InviteEvent)
    case savedGame(SavedGameEvent)
    case turnBased(TurnBasedEvent)

    public enum ChallengeEvent: Equatable {
      case didComplete(GKChallenge, issuedByFriend: GKPlayer)
      case didReceive(GKChallenge)
      case issuedChallengeWasCompleted(GKChallenge, byFriend: GKPlayer)
      case wantsToPlay(GKChallenge)
    }

    public enum InviteEvent: Equatable {
      case didAccept(GKInvite)
      case didRequestMatchWithRecipients([GKPlayer])
    }

    public enum SavedGameEvent: Equatable {
      case didModifySavedGame(GKSavedGame)
      case hasConflictingSavedGames([GKSavedGame])
    }

    public enum TurnBasedEvent: Equatable {
      case didRequestMatchWithOtherPlayers([GKPlayer])
      case matchEnded(TurnBasedMatch)
      case receivedExchangeCancellation(GKTurnBasedExchange, match: TurnBasedMatch)
      case receivedExchangeReplies([GKTurnBasedExchangeReply], match: TurnBasedMatch)
      case receivedExchangeRequest(GKTurnBasedExchange, match: TurnBasedMatch)
      case receivedTurnEventForMatch(TurnBasedMatch, didBecomeActive: Bool)
      case wantsToQuitMatch(TurnBasedMatch)
    }
  }
}

public struct TurnBasedMatchClient {
  public var endMatchInTurn: (EndMatchInTurnRequest) -> Effect<Void, Error>
  public var endTurn: (EndTurnRequest) -> Effect<Void, Error>
  public var load: (TurnBasedMatch.Id) -> Effect<TurnBasedMatch, Error>
  public var loadMatches: () -> Effect<[TurnBasedMatch], Error>
  public var participantQuitInTurn:
    (TurnBasedMatch.Id, Data)
      -> Effect<Error?, Never>
  public var participantQuitOutOfTurn:
    (TurnBasedMatch.Id)
      -> Effect<Error?, Never>
  public var rematch: (TurnBasedMatch.Id) -> Effect<TurnBasedMatch, Error>
  public var remove: (TurnBasedMatch) -> Effect<Void, Error>
  public var saveCurrentTurn: (TurnBasedMatch.Id, Data) -> Effect<Void, Error>
  public var sendReminder: (SendReminderRequest) -> Effect<Void, Error>

  public struct EndMatchInTurnRequest: Equatable {
    // TODO: public var matchOutcomes: [GKTurnBasedMatch.Outcome] or [String: GKTurnBasedMatch.Outcome]
    public var localPlayerMatchOutcome: GKTurnBasedMatch.Outcome
    public var localPlayerId: Player.Id
    public var matchId: TurnBasedMatch.Id
    public var matchData: Data
    public var message: String?

    public init(
      for matchId: TurnBasedMatch.Id,
      matchData: Data,
      localPlayerId: Player.Id,
      localPlayerMatchOutcome: GKTurnBasedMatch.Outcome,
      message: String?
    ) {
      self.localPlayerMatchOutcome = localPlayerMatchOutcome
      self.localPlayerId = localPlayerId
      self.matchId = matchId
      self.matchData = matchData
      self.message = message
    }
  }

  public struct EndTurnRequest: Equatable {
    public var matchId: TurnBasedMatch.Id
    public var matchData: Data
    public var message: String

    public init(
      for matchId: TurnBasedMatch.Id,
      matchData: Data,
      message: String
    ) {
      self.matchId = matchId
      self.matchData = matchData
      self.message = message
    }
  }

  public struct SendReminderRequest: Equatable {
    public var arguments: [String]
    public var key: String
    public var matchId: TurnBasedMatch.Id
    public var participantsAtIndices: [Int]

    public init(
      for matchId: TurnBasedMatch.Id,
      to participantsAtIndices: [Int],
      localizableMessageKey key: String,
      arguments: [String]
    ) {
      self.arguments = arguments
      self.key = key
      self.matchId = matchId
      self.participantsAtIndices = participantsAtIndices
    }
  }
}

public struct TurnBasedMatchmakerViewControllerClient {
  public var present: (_ showExistingMatches: Bool) -> Effect<DelegateEvent, Never>
  public var dismiss: Effect<Never, Never>

  public enum DelegateEvent: Equatable {
    case wasCancelled
    case didFailWithError(NSError)
  }

  public func present(showExistingMatches: Bool = true) -> Effect<DelegateEvent, Never> {
    self.present(showExistingMatches)
  }
}
