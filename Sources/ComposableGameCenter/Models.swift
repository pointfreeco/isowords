import FirstPartyMocks
import GameKit
import Overture
import Tagged

@dynamicMemberLookup
public struct LocalPlayer: Equatable {
  public var isAuthenticated: Bool
  public var isMultiplayerGamingRestricted: Bool
  public var player: Player
  public let rawValue: GKLocalPlayer?

  public init(rawValue: GKLocalPlayer) {
    self.isAuthenticated = rawValue.isAuthenticated
    self.isMultiplayerGamingRestricted = rawValue.isMultiplayerGamingRestricted
    self.player = .init(rawValue: rawValue)
    self.rawValue = rawValue
  }

  public init(
    isAuthenticated: Bool,
    isMultiplayerGamingRestricted: Bool,
    player: Player
  ) {
    self.isAuthenticated = isAuthenticated
    self.isMultiplayerGamingRestricted = isMultiplayerGamingRestricted
    self.player = player
    self.rawValue = nil
  }

  public subscript<Value>(dynamicMember keyPath: WritableKeyPath<Player, Value>) -> Value {
    get { self.player[keyPath: keyPath] }
    set { self.player[keyPath: keyPath] = newValue }
  }
}

public struct Player: Equatable {
  public typealias Id = Tagged<Player, String>

  public var alias: String
  public var displayName: String
  public var gamePlayerId: Id
  public let rawValue: GKPlayer?

  public init(rawValue: GKPlayer) {
    self.alias = rawValue.alias
    self.displayName = rawValue.displayName
    self.gamePlayerId = .init(rawValue: rawValue.gamePlayerID)
    self.rawValue = rawValue
  }

  public init(
    alias: String,
    displayName: String,
    gamePlayerId: Id
  ) {
    self.alias = alias
    self.displayName = displayName
    self.gamePlayerId = gamePlayerId
    self.rawValue = nil
  }

  public static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.displayName == rhs.displayName
  }
}

public struct TurnBasedMatch: Equatable {
  public typealias Id = Tagged<TurnBasedMatch, String>

  public var creationDate: Date
  public var currentParticipant: TurnBasedParticipant?
  public var matchData: Data?
  public var matchId: Id
  public var message: String?
  public var participants: [TurnBasedParticipant]
  public let rawValue: GKTurnBasedMatch?
  public var status: GKTurnBasedMatch.Status

  public init(rawValue: GKTurnBasedMatch) {
    self.creationDate = rawValue.creationDate
    self.currentParticipant = rawValue.currentParticipant.map(TurnBasedParticipant.init(rawValue:))
    self.matchData = rawValue.matchData
    self.matchId = .init(rawValue: rawValue.matchID)
    self.message = rawValue.message
    self.participants = rawValue.participants.map(TurnBasedParticipant.init(rawValue:))
    self.rawValue = rawValue
    self.status = rawValue.status
  }

  public init(
    creationDate: Date,
    currentParticipant: TurnBasedParticipant?,
    matchData: Data?,
    matchId: Id,
    message: String? = nil,
    participants: [TurnBasedParticipant],
    status: GKTurnBasedMatch.Status
  ) {
    self.creationDate = creationDate
    self.currentParticipant = currentParticipant
    self.matchData = matchData
    self.matchId = matchId
    self.message = message
    self.participants = participants
    self.rawValue = nil
    self.status = status
  }
}

public struct TurnBasedParticipant: Equatable {
  public var lastTurnDate: Date?
  public var matchOutcome: GKTurnBasedMatch.Outcome
  public var player: Player?
  public let rawValue: GKTurnBasedParticipant?
  public var status: GKTurnBasedParticipant.Status
  public var timeoutDate: Date?

  public init(rawValue: GKTurnBasedParticipant) {
    self.lastTurnDate = rawValue.lastTurnDate
    self.matchOutcome = rawValue.matchOutcome
    self.player = rawValue.player.map(Player.init(rawValue:))
    self.rawValue = rawValue
    self.status = rawValue.status
    self.timeoutDate = rawValue.timeoutDate
  }

  public init(
    lastTurnDate: Date?,
    matchOutcome: GKTurnBasedMatch.Outcome,
    player: Player?,
    status: GKTurnBasedParticipant.Status,
    timeoutDate: Date?
  ) {
    self.lastTurnDate = lastTurnDate
    self.matchOutcome = matchOutcome
    self.player = player
    self.status = status
    self.timeoutDate = timeoutDate
    self.rawValue = nil
  }
}

extension Player {
  public static let mock = local

  public static let local = Self(
    alias: "blob",
    displayName: "Blob",
    gamePlayerId: "A:_deadbeefdeadbeefdeadbeefdeadbeef"
  )

  public static let remote = Self(
    alias: "blob_jr",
    displayName: "Blob Jr.",
    gamePlayerId: "123456789123456789"
  )
}

extension LocalPlayer {
  public static let mock = authenticated

  public static let authenticated = Self(
    isAuthenticated: true,
    isMultiplayerGamingRestricted: false,
    player: .local
  )

  public static let notAuthenticated = Self(
    isAuthenticated: false,
    isMultiplayerGamingRestricted: false,
    player: .local
  )
}

extension TurnBasedMatch {
  public static let mock = new

  public static let new = Self(
    creationDate: .mock,
    currentParticipant: update(.local) { $0.player = .local },
    matchData: nil,
    matchId: "deadbeef-dead-beef-dead-beefdeadbeef",
    message: nil,
    participants: [
      update(.local) { $0.player = .local },
      update(.remote) { $0.player = .remote },
    ],
    status: .open
  )
}

extension TurnBasedParticipant {
  public static let local = Self(
    lastTurnDate: nil,
    matchOutcome: .none,
    player: .local,
    status: .active,
    timeoutDate: nil
  )

  public static let remote = Self(
    lastTurnDate: nil,
    matchOutcome: .none,
    player: .remote,
    status: .active,
    timeoutDate: nil
  )
}
