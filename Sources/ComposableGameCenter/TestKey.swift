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

  public static let testValue = Self()
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

  public static let testValue = Self()
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

  public static let testValue = Self()
}

extension TurnBasedMatchmakerViewControllerClient {
  public static let noop = Self(
    present: { _ in },
    dismiss: {}
  )

  public static let testValue = Self()
}
