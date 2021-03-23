extension GameCenterClient {
  public static let noop = Self(
    gameCenterViewController: .noop,
    localPlayer: .noop,
    reportAchievements: { _ in .none },
    showNotificationBanner: { _ in .none },
    turnBasedMatch: .noop,
    turnBasedMatchmakerViewController: .noop
  )
}

extension GameCenterViewControllerClient {
  public static let noop = Self(
    present: .none,
    dismiss: .none
  )
}

extension LocalPlayerClient {
  public static let noop = Self(
    authenticate: .none,
    listener: .none,
    localPlayer: {
      LocalPlayer(
        isAuthenticated: false,
        isMultiplayerGamingRestricted: false,
        player: Player(
          alias: "", displayName: "", gamePlayerId: ""
        )
      )
    },
    presentAuthenticationViewController: .none
  )
}

extension TurnBasedMatchClient {
  public static let noop = Self(
    endMatchInTurn: { _ in .none },
    endTurn: { _ in .none },
    load: { _ in .none },
    loadMatches: { .none },
    participantQuitInTurn: { _, _ in .none },
    participantQuitOutOfTurn: { _ in .none },
    rematch: { _ in .none },
    remove: { _ in .none },
    saveCurrentTurn: { _, _ in .none },
    sendReminder: { _ in .none }
  )
}

extension TurnBasedMatchmakerViewControllerClient {
  public static let noop = Self(
    _present: { _ in .none },
    dismiss: .none
  )
}

#if DEBUG
  import XCTestDynamicOverlay

  extension GameCenterClient {
    public static let failing = Self(
      gameCenterViewController: .failing,
      localPlayer: .failing,
      reportAchievements: { _ in .failing("\(Self.self).reportAchievements is unimplemented") },
      showNotificationBanner: { _ in
        .failing("\(Self.self).showNotificationBanner is unimplemented")
      },
      turnBasedMatch: .failing,
      turnBasedMatchmakerViewController: .failing
    )
  }

  extension GameCenterViewControllerClient {
    public static let failing = Self(
      present: .failing("\(Self.self).present is unimplemented"),
      dismiss: .failing("\(Self.self).dismiss is unimplemented")
    )
  }

  extension LocalPlayerClient {
    public static let failing = Self(
      authenticate: .failing("\(Self.self).authenticate is unimplemented"),
      listener: .failing("\(Self.self).listener is unimplemented"),
      localPlayer: {
        XCTFail("\(Self.self).localPlayer is unimplemented")
        return .notAuthenticated
      },
      presentAuthenticationViewController:
        .failing("\(Self.self).presentAuthenticationViewController is unimplemented")
    )
  }

  extension TurnBasedMatchClient {
    public static let failing = Self(
      endMatchInTurn: { _ in .failing("\(Self.self).endMatchInTurn is unimplemented") },
      endTurn: { _ in .failing("\(Self.self).endTurn is unimplemented") },
      load: { _ in .failing("\(Self.self).load is unimplemented") },
      loadMatches: { .failing("\(Self.self).loadMatches is unimplemented") },
      participantQuitInTurn: { _, _ in
        .failing("\(Self.self).participantQuitInTurn is unimplemented")
      },
      participantQuitOutOfTurn: { _ in
        .failing("\(Self.self).participantQuitOutOfTurn is unimplemented")
      },
      rematch: { _ in .failing("\(Self.self).rematch is unimplemented") },
      remove: { _ in .failing("\(Self.self).remove is unimplemented") },
      saveCurrentTurn: { _, _ in .failing("\(Self.self).saveCurrentTurn is unimplemented") },
      sendReminder: { _ in .failing("\(Self.self).sendReminder is unimplemented") }
    )
  }

  extension TurnBasedMatchmakerViewControllerClient {
    public static let failing = Self(
      _present: { _ in .failing("\(Self.self).present is unimplemented") },
      dismiss: .failing("\(Self.self).dismiss is unimplemented")
    )
  }
#endif
