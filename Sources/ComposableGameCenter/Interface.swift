import Combine
import ComposableArchitecture
import GameKit
import Tagged

public struct GameCenterClient {
  public var gameCenterViewController: GameCenterViewControllerClient
  public var localPlayer: LocalPlayerClient
  @available(*, deprecated) public var reportAchievements: ([GKAchievement]) -> Effect<Void, Error>
  public var reportAchievementsAsync: @Sendable ([GKAchievement]) async throws -> Void
  @available(*, deprecated) public var showNotificationBanner: (NotificationBannerRequest) -> Effect<Void, Never>
  public var showNotificationBannerAsync: @Sendable (NotificationBannerRequest) async -> Void
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
  @available(*, deprecated) public var present: Effect<DelegateEvent, Never>
  public var presentAsync: @Sendable () async -> Void
  @available(*, deprecated) public var dismiss: Effect<Never, Never>
  public var dismissAsync: @Sendable () async -> Void

  public enum DelegateEvent: Equatable {
    case didFinish
  }
}

public struct LocalPlayerClient {
  public var authenticate: @Sendable () async throws -> Void
  public var listener: @Sendable () -> AsyncStream<ListenerEvent>
  @available(*, deprecated) public var localPlayer: () -> LocalPlayer
  public var localPlayerAsync: @Sendable () async -> LocalPlayer
  @available(*, deprecated) public var presentAuthenticationViewController: Effect<Never, Never>
  public var presentAuthenticationViewControllerAsync: @Sendable () async -> Void

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
  @available(*, deprecated) public var endMatchInTurn: (EndMatchInTurnRequest) -> Effect<Void, Error>
  public var endMatchInTurnAsync: @Sendable (EndMatchInTurnRequest) async throws -> Void
  @available(*, deprecated) public var endTurn: (EndTurnRequest) -> Effect<Void, Error>
  public var endTurnAsync: @Sendable (EndTurnRequest) async throws -> Void
  @available(*, deprecated) public var load: (TurnBasedMatch.Id) -> Effect<TurnBasedMatch, Error>
  public var loadAsync : @Sendable (TurnBasedMatch.Id) async throws -> TurnBasedMatch
  @available(*, deprecated) public var loadMatches: () -> Effect<[TurnBasedMatch], Error>
  public var loadMatchesAsync: @Sendable () async throws -> [TurnBasedMatch]
  @available(*, deprecated) public var participantQuitInTurn: (TurnBasedMatch.Id, Data) -> Effect<Error?, Never>
  public var participantQuitInTurnAsync: @Sendable (TurnBasedMatch.Id, Data) async throws -> Void
  @available(*, deprecated) public var participantQuitOutOfTurn: (TurnBasedMatch.Id) -> Effect<Error?, Never>
  public var participantQuitOutOfTurnAsync: @Sendable (TurnBasedMatch.Id) async throws -> Void
  @available(*, deprecated) public var rematch: (TurnBasedMatch.Id) -> Effect<TurnBasedMatch, Error>
  public var rematchAsync: @Sendable (TurnBasedMatch.Id) async throws -> TurnBasedMatch
  @available(*, deprecated) public var remove: (TurnBasedMatch) -> Effect<Void, Error>
  public var removeAsync: @Sendable (TurnBasedMatch) async throws -> Void
  @available(*, deprecated) public var saveCurrentTurn: (TurnBasedMatch.Id, Data) -> Effect<Void, Error>
  public var saveCurrentTurnAsync: @Sendable (TurnBasedMatch.Id, Data) async throws -> Void
  @available(*, deprecated) public var sendReminder: (SendReminderRequest) -> Effect<Void, Error>
  public var sendReminderAsync: @Sendable (SendReminderRequest) async throws -> Void

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
  @available(*, deprecated) public var present: (_ showExistingMatches: Bool) -> Effect<DelegateEvent, Never>
  public var presentAsync: @Sendable (_ showExistingMatches: Bool) async throws -> Void
  @available(*, deprecated) public var dismiss: Effect<Never, Never>
  public var dismissAsync: @Sendable () async -> Void

  public enum DelegateEvent: Equatable {
    case wasCancelled
    case didFailWithError(NSError)
  }

  public func present(showExistingMatches: Bool = true) -> Effect<DelegateEvent, Never> {
    self.present(showExistingMatches)
  }
}
