import Dependencies
import XCTestDynamicOverlay

extension DependencyValues {
  public var gameCenter: GameCenterClient {
    get { self[GameCenterClient.self] }
    set { self[GameCenterClient.self] = newValue }
  }
}

extension GameCenterClient: TestDependencyKey {
  public static let previewValue = Self.noop

  public static let testValue = Self(
    gameCenterViewController: .testValue,
    localPlayer: .testValue,
    reportAchievements: unimplemented("\(Self.self).reportAchievements"),
    showNotificationBanner: unimplemented("\(Self.self).showNotificationBanner"),
    turnBasedMatch: .testValue,
    turnBasedMatchmakerViewController: .testValue
  )
}

extension GameCenterClient {
  public static let noop = Self(
    gameCenterViewController: .noop,
    localPlayer: .noop,
    reportAchievements: { _ in },
    showNotificationBanner: { _ in },
    turnBasedMatch: .noop,
    turnBasedMatchmakerViewController: .noop
  )
}

extension GameCenterViewControllerClient {
  public static let noop = Self(
    present: {},
    dismiss: {}
  )

  public static let testValue = Self(
    present: unimplemented("\(Self.self).present"),
    dismiss: unimplemented("\(Self.self).dismiss")
  )
}

extension LocalPlayerClient {
  public static let noop = Self(
    authenticate: {},
    listener: { .finished },
    localPlayer: {
      LocalPlayer(
        isAuthenticated: false,
        isMultiplayerGamingRestricted: false,
        player: Player(
          alias: "", displayName: "", gamePlayerId: ""
        )
      )
    },
    presentAuthenticationViewController: {}
  )

  public static let testValue = Self(
    authenticate: unimplemented("\(Self.self).authenticate"),
    listener: unimplemented("\(Self.self).listener", placeholder: .finished),
    localPlayer: unimplemented("\(Self.self).localPlayer", placeholder: .notAuthenticated),
    presentAuthenticationViewController: unimplemented(
      "\(Self.self).presentAuthenticationViewController"
    )
  )
}

extension TurnBasedMatchClient {
  public static let noop = Self(
    endMatchInTurn: { _ in },
    endTurn: { _ in },
    load: { _ in try await Task.never() },
    loadMatches: { [] },
    participantQuitInTurn: { _, _ in },
    participantQuitOutOfTurn: { _ in },
    rematch: { _ in try await Task.never() },
    remove: { _ in },
    saveCurrentTurn: { _, _ in },
    sendReminder: { _ in }
  )

  public static let testValue = Self(
    endMatchInTurn: unimplemented("\(Self.self).endMatchInTurn"),
    endTurn: unimplemented("\(Self.self).endTurn"),
    load: unimplemented("\(Self.self).load"),
    loadMatches: unimplemented("\(Self.self).loadMatches"),
    participantQuitInTurn: unimplemented("\(Self.self).participantQuitInTurn"),
    participantQuitOutOfTurn: unimplemented("\(Self.self).participantQuitOutOfTurn"),
    rematch: unimplemented("\(Self.self).rematch"),
    remove: unimplemented("\(Self.self).remove"),
    saveCurrentTurn: unimplemented("\(Self.self).saveCurrentTurn"),
    sendReminder: unimplemented("\(Self.self).sendReminder")
  )
}

extension TurnBasedMatchmakerViewControllerClient {
  public static let noop = Self(
    present: { _ in },
    dismiss: {}
  )

  public static let testValue = Self(
    present: unimplemented("\(Self.self).present"),
    dismiss: unimplemented("\(Self.self).dismiss")
  )
}
