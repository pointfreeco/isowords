import XCTestDynamicOverlay

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
}

extension TurnBasedMatchmakerViewControllerClient {
  public static let noop = Self(
    present: { _ in },
    dismiss: {}
  )
}

extension GameCenterClient {
  public static let unimplemented = Self(
    gameCenterViewController: .unimplemented,
    localPlayer: .unimplemented,
    reportAchievements: XCTUnimplemented("\(Self.self).reportAchievements"),
    showNotificationBanner: XCTUnimplemented("\(Self.self).showNotificationBanner"),
    turnBasedMatch: .unimplemented,
    turnBasedMatchmakerViewController: .unimplemented
  )
}

extension GameCenterViewControllerClient {
  public static let unimplemented = Self(
    present: XCTUnimplemented("\(Self.self).present"),
    dismiss: XCTUnimplemented("\(Self.self).dismiss")
  )
}

extension LocalPlayerClient {
  public static let unimplemented = Self(
    authenticate: XCTUnimplemented("\(Self.self).authenticate"),
    listener: XCTUnimplemented("\(Self.self).listener", placeholder: .finished),
    localPlayer: XCTUnimplemented("\(Self.self).localPlayer", placeholder: .notAuthenticated),
    presentAuthenticationViewController: XCTUnimplemented(
      "\(Self.self).presentAuthenticationViewController"
    )
  )
}

extension TurnBasedMatchClient {
  public static let unimplemented = Self(
    endMatchInTurn: XCTUnimplemented("\(Self.self).endMatchInTurn"),
    endTurn: XCTUnimplemented("\(Self.self).endTurn"),
    load: XCTUnimplemented("\(Self.self).load"),
    loadMatches: XCTUnimplemented("\(Self.self).loadMatches"),
    participantQuitInTurn: XCTUnimplemented("\(Self.self).participantQuitInTurn"),
    participantQuitOutOfTurn: XCTUnimplemented("\(Self.self).participantQuitOutOfTurn"),
    rematch: XCTUnimplemented("\(Self.self).rematch"),
    remove: XCTUnimplemented("\(Self.self).remove"),
    saveCurrentTurn: XCTUnimplemented("\(Self.self).saveCurrentTurn"),
    sendReminder: XCTUnimplemented("\(Self.self).sendReminder")
  )
}

extension TurnBasedMatchmakerViewControllerClient {
  public static let unimplemented = Self(
    present: XCTUnimplemented("\(Self.self).present"),
    dismiss: XCTUnimplemented("\(Self.self).dismiss")
  )
}
