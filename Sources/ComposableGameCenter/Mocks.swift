extension GameCenterClient {
  public static let noop = Self(
    gameCenterViewController: .noop,
    localPlayer: .noop,
    reportAchievements: { _ in .none },
    reportAchievementsAsync: { _ in },
    showNotificationBanner: { _ in .none },
    showNotificationBannerAsync: { _ in },
    turnBasedMatch: .noop,
    turnBasedMatchmakerViewController: .noop
  )
}

extension GameCenterViewControllerClient {
  public static let noop = Self(
    present: .none,
    presentAsync: {},
    dismiss: .none,
    dismissAsync: {}
  )
}

extension LocalPlayerClient {
  public static let noop = Self(
    authenticate: .none,
    authenticateAsync: {},
    listener: .none,
    listenerAsync: { AsyncStream { _ in } },
    localPlayer: {
      LocalPlayer(
        isAuthenticated: false,
        isMultiplayerGamingRestricted: false,
        player: Player(
          alias: "", displayName: "", gamePlayerId: ""
        )
      )
    },
    localPlayerAsync: {
      LocalPlayer(
        isAuthenticated: false,
        isMultiplayerGamingRestricted: false,
        player: Player(
          alias: "", displayName: "", gamePlayerId: ""
        )
      )
    },
    presentAuthenticationViewController: .none,
    presentAuthenticationViewControllerAsync: {}
  )
}

extension TurnBasedMatchClient {
  public static let noop = Self(
    endMatchInTurn: { _ in .none },
    endMatchInTurnAsync: { _ in },
    endTurn: { _ in .none },
    endTurnAsync: { _ in },
    load: { _ in .none },
    loadAsync: { _ in try await Task.never() },
    loadMatches: { .none },
    loadMatchesAsync: { [] },
    participantQuitInTurn: { _, _ in .none },
    participantQuitInTurnAsync: { _, _ in },
    participantQuitOutOfTurn: { _ in .none },
    participantQuitOutOfTurnAsync: { _ in },
    rematch: { _ in .none },
    rematchAsync: { _ in try await Task.never() },
    remove: { _ in .none },
    removeAsync: { _ in },
    saveCurrentTurn: { _, _ in .none },
    saveCurrentTurnAsync: { _, _ in },
    sendReminder: { _ in .none },
    sendReminderAsync: { _ in }
  )
}

extension TurnBasedMatchmakerViewControllerClient {
  public static let noop = Self(
    present: { _ in .none },
    presentAsync: { _ in },
    dismiss: .none,
    dismissAsync: {}
  )
}

#if DEBUG
  import XCTestDynamicOverlay

  extension GameCenterClient {
    public static let failing = Self(
      gameCenterViewController: .failing,
      localPlayer: .failing,
      reportAchievements: { _ in .failing("\(Self.self).reportAchievements is unimplemented") },
      reportAchievementsAsync: XCTUnimplemented("\(Self.self).reportAchievementsAsync"),
      showNotificationBanner: { _ in
        .failing("\(Self.self).showNotificationBanner is unimplemented")
      },
      showNotificationBannerAsync: XCTUnimplemented("\(Self.self).showNotificationBannerAsync"),
      turnBasedMatch: .failing,
      turnBasedMatchmakerViewController: .failing
    )
  }

  extension GameCenterViewControllerClient {
    public static let failing = Self(
      present: .failing("\(Self.self).present is unimplemented"),
      presentAsync: XCTUnimplemented("\(Self.self).presentAsync"),
      dismiss: .failing("\(Self.self).dismiss is unimplemented"),
      dismissAsync: XCTUnimplemented("\(Self.self).dismissAsync")
    )
  }

  extension LocalPlayerClient {
    public static let failing = Self(
      authenticate: .failing("\(Self.self).authenticate is unimplemented"),
      authenticateAsync: XCTUnimplemented("\(Self.self).authenticateAsync"),
      listener: .failing("\(Self.self).listener is unimplemented"),
      listenerAsync: XCTUnimplemented("\(Self.self).listenerAsync", placeholder: .finished),
      localPlayer: {
        XCTFail("\(Self.self).localPlayer is unimplemented")
        return .notAuthenticated
      },
      localPlayerAsync: XCTUnimplemented(
        "\(Self.self).localPlayerAsync", placeholder: .notAuthenticated
      ),
      presentAuthenticationViewController:
        .failing("\(Self.self).presentAuthenticationViewController is unimplemented"),
      presentAuthenticationViewControllerAsync: XCTUnimplemented(
        "\(Self.self).presentAuthenticationViewControllerAsync"
      )
    )
  }

  extension TurnBasedMatchClient {
    public static let failing = Self(
      endMatchInTurn: { _ in .failing("\(Self.self).endMatchInTurn is unimplemented") },
      endMatchInTurnAsync: XCTUnimplemented("\(Self.self).endMatchInTurnAsync"),
      endTurn: { _ in .failing("\(Self.self).endTurn is unimplemented") },
      endTurnAsync: XCTUnimplemented("\(Self.self).endTurnAsync"),
      load: { _ in .failing("\(Self.self).load is unimplemented") },
      loadAsync: XCTUnimplemented("\(Self.self).loadAsync"),
      loadMatches: { .failing("\(Self.self).loadMatches is unimplemented") },
      loadMatchesAsync: XCTUnimplemented("\(Self.self).loadMatchesAsync"),
      participantQuitInTurn: { _, _ in
        .failing("\(Self.self).participantQuitInTurn is unimplemented")
      },
      participantQuitInTurnAsync: XCTUnimplemented("\(Self.self).participantQuitInTurnAsync"),
      participantQuitOutOfTurn: { _ in
        .failing("\(Self.self).participantQuitOutOfTurn is unimplemented")
      },
      participantQuitOutOfTurnAsync: XCTUnimplemented("\(Self.self).participantQuitOutOfTurnAsync"),
      rematch: { _ in .failing("\(Self.self).rematch is unimplemented") },
      rematchAsync: XCTUnimplemented("\(Self.self).rematchAsync"),
      remove: { _ in .failing("\(Self.self).remove is unimplemented") },
      removeAsync: XCTUnimplemented("\(Self.self).removeAsync"),
      saveCurrentTurn: { _, _ in .failing("\(Self.self).saveCurrentTurn is unimplemented") },
      saveCurrentTurnAsync: XCTUnimplemented("\(Self.self).saveCurrentTurnAsync"),
      sendReminder: { _ in .failing("\(Self.self).sendReminder is unimplemented") },
      sendReminderAsync: XCTUnimplemented("\(Self.self).sendReminderAsync")
    )
  }

  extension TurnBasedMatchmakerViewControllerClient {
    public static let failing = Self(
      present: { _ in .failing("\(Self.self).present is unimplemented") },
      presentAsync: XCTUnimplemented("\(Self.self).presentAsync"),
      dismiss: .failing("\(Self.self).dismiss is unimplemented"),
      dismissAsync: XCTUnimplemented("\(Self.self).dismissAsync")
    )
  }
#endif
