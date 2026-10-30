import ApiClient
import ClientModels
import ComposableArchitecture
import ComposableUserNotifications
import ConcurrencyExtras
import CustomDump
import Dependencies
import SwiftUI
import UserNotifications
import XCTest

@testable import DailyChallengeFeature
@testable import NotificationsAuthAlert
@testable import SharedModels

class DailyChallengeFeatureTests: XCTestCase {
  let clock = TestClock<Duration>()

  @MainActor
  func testOnAppear() async {
    let store = withDependencies {
      $0.apiClient.override(
        route: .dailyChallenge(.today(language: .en)),
        withResponse: { try await OK([FetchTodaysDailyChallengeResponse.played]) }
      )
      $0.userNotifications.getNotificationSettings = {
        .init(authorizationStatus: .authorized)
      }
    } operation: {
      TestStore(initialState: DailyChallengeReducer.State()) {
        DailyChallengeReducer()
      }
    }

    await store.mountTask?.value
    store.expect {
      $0.dailyChallenges = [.played]
      $0.userNotificationSettings = .init(authorizationStatus: .authorized)
    }
  }

  @MainActor
  func testTapGameThatWasPlayed() async {
    var dailyChallengeResponse = FetchTodaysDailyChallengeResponse.played
    dailyChallengeResponse.dailyChallenge.endsAt = Date().addingTimeInterval(60 * 60 * 2 + 1)

    let store = withDependencies {
      $0.mountDependencies(dailyChallenges: [dailyChallengeResponse])
    } operation: {
      TestStore(
        initialState: DailyChallengeReducer.State(dailyChallenges: [dailyChallengeResponse])
      ) {
        DailyChallengeReducer()
      }
    }
    await store.mountTask?.value
    store.expect {
      $0.userNotificationSettings = .init(authorizationStatus: .authorized)
    }

    withExhaustivity(.none) {
      store.send(.gameButtonTapped(.unlimited))
    }
    XCTAssertEqual(store.destination?.alert?.title, Text("Already played"))
  }

  @MainActor
  func testTapGameThatWasNotStarted() async {
    var inProgressGame = InProgressGame.mock
    inProgressGame.gameStartTime = Date(timeIntervalSinceReferenceDate: 0)
    inProgressGame.gameContext = .dailyChallenge(.init(rawValue: .dailyChallengeId))

    let store = withDependencies {
      $0.mountDependencies(dailyChallenges: [.notStarted])
      $0.apiClient.override(
        route: .dailyChallenge(.start(gameMode: .unlimited, language: .en)),
        withResponse: {
          try await OK(
            StartDailyChallengeResponse(
              dailyChallenge: .init(
                createdAt: .mock,
                endsAt: .mock,
                gameMode: .unlimited,
                gameNumber: 42,
                id: .init(rawValue: .dailyChallengeId),
                language: .en,
                puzzle: .mock
              ),
              dailyChallengePlayId: .init(rawValue: .deadbeef)
            )
          )
        }
      )
      $0.fileClient.load = { @Sendable _ in
        struct FileNotFound: Error {}
        throw FileNotFound()
      }
    } operation: {
      TestStore(
        initialState: DailyChallengeReducer.State(dailyChallenges: [.notStarted])
      ) {
        DailyChallengeReducer()
          .environment(\.continuousClock, self.clock)
      }
    }
    await store.mountTask?.value
    store.expect {
      $0.userNotificationSettings = .init(authorizationStatus: .authorized)
    }

    store.send(.gameButtonTapped(.unlimited)) {
      $0.gameModeIsLoading = .unlimited
    }

    await self.clock.advance()
    await store.receive(
      key: DailyChallengeReducer.StartGame.self,
      value: .equals(inProgressGame),
      timeout: .seconds(1)
    ) {
      $0.gameModeIsLoading = nil
    }
  }

  @MainActor
  func testTapGameThatWasStarted_NotPlayed_HasLocalGame() async {
    var inProgressGame = InProgressGame.mock
    inProgressGame.gameStartTime = .mock
    inProgressGame.gameContext = .dailyChallenge(.init(rawValue: .dailyChallengeId))
    inProgressGame.moves = [
      .highScoringMove
    ]

    let store = withDependencies {
      $0.mountDependencies(dailyChallenges: [.started])
      $0.fileClient.load = { @Sendable [inProgressGame] _ in
        try JSONEncoder().encode(SavedGamesState(dailyChallengeUnlimited: inProgressGame))
      }
    } operation: {
      TestStore(
        initialState: DailyChallengeReducer.State(
          dailyChallenges: [.started],
          inProgressDailyChallengeUnlimited: inProgressGame
        )
      ) {
        DailyChallengeReducer()
      }
    }
    await store.mountTask?.value
    store.expect {
      $0.userNotificationSettings = .init(authorizationStatus: .authorized)
    }

    store.send(.gameButtonTapped(.unlimited)) {
      $0.gameModeIsLoading = .unlimited
    }

    await store.receive(
      key: DailyChallengeReducer.StartGame.self,
      value: .equals(inProgressGame),
      timeout: .seconds(1)
    ) {
      $0.gameModeIsLoading = nil
    }
  }

  @MainActor
  func testNotifications_OpenThenClose() async {
    let store = withDependencies {
      $0.mountDependencies(dailyChallenges: [])
    } operation: {
      TestStore(initialState: DailyChallengeReducer.State()) {
        DailyChallengeReducer()
      }
    }
    await store.mountTask?.value
    store.expect {
      $0.userNotificationSettings = .init(authorizationStatus: .authorized)
    }

    store.send(.notificationButtonTapped) {
      $0.destination = .notificationsAuthAlert(NotificationsAuthAlert.State.DebugSnapshot())
    }
    store.modify {
      $0.destination = nil
    }
  }

  @MainActor
  func testNotifications_GrantAccess() async {
    let didRegisterForRemoteNotifications = ActorIsolated(false)
    let authorizationStatus = LockIsolated<UNAuthorizationStatus>(.notDetermined)

    let store = withDependencies {
      $0.mountDependencies(dailyChallenges: [])
      $0.userNotifications.getNotificationSettings = {
        .init(authorizationStatus: authorizationStatus.value)
      }
      $0.userNotifications.requestAuthorization = { _ in
        authorizationStatus.setValue(.authorized)
        return true
      }
      $0.remoteNotifications.register = {
        await didRegisterForRemoteNotifications.setValue(true)
      }
    } operation: {
      TestStore(initialState: DailyChallengeReducer.State()) {
        DailyChallengeReducer()
      }
    }
    await store.mountTask?.value
    store.expect {
      $0.userNotificationSettings = .init(authorizationStatus: .notDetermined)
    }

    store.send(.notificationButtonTapped) {
      $0.destination = .notificationsAuthAlert(NotificationsAuthAlert.State.DebugSnapshot())
    }
    await store.send(.destination(.notificationsAuthAlert(.turnOnNotificationsButtonTapped)))?
      .value
    store.expect {
      $0.destination = nil
      $0.userNotificationSettings = .init(authorizationStatus: .authorized)
    }

    await didRegisterForRemoteNotifications.withValue { expectNoDifference($0, true) }
  }

  @MainActor
  func testNotifications_DenyAccess() async {
    let authorizationStatus = LockIsolated<UNAuthorizationStatus>(.notDetermined)

    let store = withDependencies {
      $0.mountDependencies(dailyChallenges: [])
      $0.userNotifications.getNotificationSettings = {
        .init(authorizationStatus: authorizationStatus.value)
      }
      $0.userNotifications.requestAuthorization = { _ in
        authorizationStatus.setValue(.denied)
        return false
      }
    } operation: {
      TestStore(initialState: DailyChallengeReducer.State()) {
        DailyChallengeReducer()
      }
    }
    await store.mountTask?.value
    store.expect {
      $0.userNotificationSettings = .init(authorizationStatus: .notDetermined)
    }

    store.send(.notificationButtonTapped) {
      $0.destination = .notificationsAuthAlert(NotificationsAuthAlert.State.DebugSnapshot())
    }
    await store.send(.destination(.notificationsAuthAlert(.turnOnNotificationsButtonTapped)))?
      .value
    store.expect {
      $0.destination = nil
      $0.userNotificationSettings = .init(authorizationStatus: .denied)
    }
  }
}

extension DependencyValues {
  fileprivate mutating func mountDependencies(
    dailyChallenges: [FetchTodaysDailyChallengeResponse]
  ) {
    self.apiClient.override(
      route: .dailyChallenge(.today(language: .en)),
      withResponse: { try await OK(dailyChallenges) }
    )
    self.userNotifications.getNotificationSettings = {
      .init(authorizationStatus: .authorized)
    }
  }
}
