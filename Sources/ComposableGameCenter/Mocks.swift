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
    listener: { AsyncStream { _ in } },
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
    endMatchInTurnAsync: { _ in },
    endTurnAsync: { _ in },
    loadAsync: { _ in try await Task.never() },
    loadMatchesAsync: { [] },
    participantQuitInTurnAsync: { _, _ in },
    participantQuitOutOfTurnAsync: { _ in },
    rematchAsync: { _ in try await Task.never() },
    removeAsync: { _ in },
    saveCurrentTurnAsync: { _, _ in },
    sendReminderAsync: { _ in }
  )
}

extension TurnBasedMatchmakerViewControllerClient {
  public static let noop = Self(
    present: { _ in },
    dismiss: {}
  )
}

#if DEBUG
  import XCTestDynamicOverlay

  extension GameCenterClient {
    public static let failing = Self(
      gameCenterViewController: .failing,
      localPlayer: .failing,
      reportAchievements: XCTUnimplemented("\(Self.self).reportAchievements"),
      showNotificationBanner: XCTUnimplemented("\(Self.self).showNotificationBanner"),
      turnBasedMatch: .failing,
      turnBasedMatchmakerViewController: .failing
    )
  }

  extension GameCenterViewControllerClient {
    public static let failing = Self(
      present: XCTUnimplemented("\(Self.self).present"),
      dismiss: XCTUnimplemented("\(Self.self).dismiss")
    )
  }

  extension LocalPlayerClient {
    public static let failing = Self(
      authenticate: XCTUnimplemented("\(Self.self).authenticate"),
      listener: XCTUnimplemented("\(Self.self).listener", placeholder: .finished),
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
      endMatchInTurnAsync: XCTUnimplemented("\(Self.self).endMatchInTurnAsync"),
      endTurnAsync: XCTUnimplemented("\(Self.self).endTurnAsync"),
      loadAsync: XCTUnimplemented("\(Self.self).loadAsync"),
      loadMatchesAsync: XCTUnimplemented("\(Self.self).loadMatchesAsync"),
      participantQuitInTurnAsync: XCTUnimplemented("\(Self.self).participantQuitInTurnAsync"),
      participantQuitOutOfTurnAsync: XCTUnimplemented("\(Self.self).participantQuitOutOfTurnAsync"),
      rematchAsync: XCTUnimplemented("\(Self.self).rematchAsync"),
      removeAsync: XCTUnimplemented("\(Self.self).removeAsync"),
      saveCurrentTurnAsync: XCTUnimplemented("\(Self.self).saveCurrentTurnAsync"),
      sendReminderAsync: XCTUnimplemented("\(Self.self).sendReminderAsync")
    )
  }

  extension TurnBasedMatchmakerViewControllerClient {
    public static let failing = Self(
      present: XCTUnimplemented("\(Self.self).present"),
      dismiss: XCTUnimplemented("\(Self.self).dismiss")
    )
  }
#endif
