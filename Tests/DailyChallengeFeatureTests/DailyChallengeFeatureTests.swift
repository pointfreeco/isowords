import ApiClient
import ClientModels
import ComposableArchitecture
import NotificationsAuthAlert
import XCTest

@testable import DailyChallengeFeature
@testable import SharedModels

@MainActor
class DailyChallengeFeatureTests: XCTestCase {
  let mainQueue = DispatchQueue.test
  let mainRunLoop = RunLoop.test

  func testOnAppear() async {
    let store = TestStore(initialState: DailyChallengeReducer.State()) {
      DailyChallengeReducer()
    } withDependencies: {
      $0.apiClient.override(
        route: .dailyChallenge(.today(language: .en)),
        withResponse: { try await OK([FetchTodaysDailyChallengeResponse.played]) }
      )
      $0.mainRunLoop = .immediate
      $0.userNotifications.getNotificationSettings = {
        .init(authorizationStatus: .authorized)
      }
    }

    await store.send(.task)

    await store.receive(\.userNotificationSettingsResponse) {
      $0.userNotificationSettings = .init(authorizationStatus: .authorized)
    }
    await store.receive(\.fetchTodaysDailyChallengeResponse.success) {
      $0.dailyChallenges = [.played]
    }
  }

  func testTapGameThatWasPlayed() async {
    var dailyChallengeResponse = FetchTodaysDailyChallengeResponse.played
    dailyChallengeResponse.dailyChallenge.endsAt = Date().addingTimeInterval(60 * 60 * 2 + 1)

    let store = TestStore(
      initialState: DailyChallengeReducer.State(dailyChallenges: [dailyChallengeResponse])
    ) {
      DailyChallengeReducer()
    }

    await store.send(.gameButtonTapped(.unlimited)) {
      $0.destination = .alert(
        .alreadyPlayed(nextStartsAt: Date().addingTimeInterval(60 * 60 * 2 + 1))
      )
    }
  }

  func testTapGameThatWasNotStarted() async {
    var inProgressGame = InProgressGame.mock
    inProgressGame.gameStartTime = self.mainRunLoop.now.date
    inProgressGame.gameContext = .dailyChallenge(.init(rawValue: .dailyChallengeId))

    let store = TestStore(
      initialState: DailyChallengeReducer.State(dailyChallenges: [.notStarted])
    ) {
      DailyChallengeReducer()
    } withDependencies: {
      $0.mainRunLoop = self.mainRunLoop.eraseToAnyScheduler()
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
    }

    await store.send(.gameButtonTapped(.unlimited)) {
      $0.gameModeIsLoading = .unlimited
    }

    await self.mainRunLoop.advance()
    await store.receive(\.startDailyChallengeResponse.success) {
      $0.gameModeIsLoading = nil
    }
    await store.receive(\.delegate.startGame)
  }

  func testTapGameThatWasStarted_NotPlayed_HasLocalGame() async {
    var inProgressGame = InProgressGame.mock
    inProgressGame.gameStartTime = .mock
    inProgressGame.gameContext = .dailyChallenge(.init(rawValue: .dailyChallengeId))
    inProgressGame.moves = [
      .highScoringMove
    ]

    let store = TestStore(
      initialState: DailyChallengeReducer.State(
        dailyChallenges: [.started],
        inProgressDailyChallengeUnlimited: inProgressGame
      )
    ) {
      DailyChallengeReducer()
    } withDependencies: {
      $0.fileClient.load = { @Sendable [inProgressGame] _ in
        try JSONEncoder().encode(SavedGamesState(dailyChallengeUnlimited: inProgressGame))
      }
      $0.mainRunLoop = .immediate
    }

    await store.send(.gameButtonTapped(.unlimited)) {
      $0.gameModeIsLoading = .unlimited
    }

    await store.receive(\.startDailyChallengeResponse.success) {
      $0.gameModeIsLoading = nil
    }
    await store.receive(\.delegate.startGame)
  }

  func testNotifications_OpenThenClose() async {
    let store = TestStore(
      initialState: DailyChallengeReducer.State()
    ) {
      DailyChallengeReducer()
    }

    await store.send(.notificationButtonTapped) {
      $0.destination = .notificationsAuthAlert(NotificationsAuthAlert.State())
    }
    await store.send(.destination(.dismiss)) {
      $0.destination = nil
    }
  }

  func testNotifications_GrantAccess() async {
    let didRegisterForRemoteNotifications = ActorIsolated(false)

    let store = TestStore(initialState: DailyChallengeReducer.State()) {
      DailyChallengeReducer()
    } withDependencies: {
      $0.userNotifications.getNotificationSettings = {
        .init(authorizationStatus: .authorized)
      }
      $0.userNotifications.requestAuthorization = { _ in true }
      $0.remoteNotifications.register = {
        await didRegisterForRemoteNotifications.setValue(true)
      }
      $0.mainRunLoop = .immediate
    }

    await store.send(.notificationButtonTapped) {
      $0.destination = .notificationsAuthAlert(NotificationsAuthAlert.State())
    }
    await store.send(
      .destination(.presented(.notificationsAuthAlert(.turnOnNotificationsButtonTapped)))
    )
    await store.receive(
      \.destination.notificationsAuthAlert.delegate.didChooseNotificationSettings
    ) {
      $0.userNotificationSettings = .init(authorizationStatus: .authorized)
    }
    await store.receive(\.destination.dismiss) {
      $0.destination = nil
    }

    await didRegisterForRemoteNotifications.withValue { XCTAssertNoDifference($0, true) }
  }

  func testNotifications_DenyAccess() async {
    let store = TestStore(initialState: DailyChallengeReducer.State()) {
      DailyChallengeReducer()
    } withDependencies: {
      $0.userNotifications.getNotificationSettings = {
        .init(authorizationStatus: .denied)
      }
      $0.userNotifications.requestAuthorization = { _ in false }
      $0.mainRunLoop = .immediate
    }

    await store.send(.notificationButtonTapped) {
      $0.destination = .notificationsAuthAlert(NotificationsAuthAlert.State())
    }
    await store.send(
      .destination(.presented(.notificationsAuthAlert(.turnOnNotificationsButtonTapped)))
    )
    await store.receive(
      \.destination.notificationsAuthAlert.delegate.didChooseNotificationSettings
    ) {
      $0.userNotificationSettings = .init(authorizationStatus: .denied)
    }
    await store.receive(\.destination.dismiss) {
      $0.destination = nil
    }
  }
}
