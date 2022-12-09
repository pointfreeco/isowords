import ApiClient
import ClientModels
import ComposableArchitecture
import XCTest

@testable import DailyChallengeFeature
@testable import SharedModels

@MainActor
class DailyChallengeFeatureTests: XCTestCase {
  let mainQueue = DispatchQueue.test
  let mainRunLoop = RunLoop.test

  func testOnAppear() async {
    let store = TestStore(
      initialState: DailyChallengeReducer.State(),
      reducer: DailyChallengeReducer()
    )

    store.dependencies.apiClient.override(
      route: .dailyChallenge(.today(language: .en)),
      withResponse: { try await OK([FetchTodaysDailyChallengeResponse.played]) }
    )
    store.dependencies.mainRunLoop = .immediate
    store.dependencies.userNotifications.getNotificationSettings = {
      .init(authorizationStatus: .authorized)
    }

    await store.send(.task)

    await store.receive(.userNotificationSettingsResponse(.init(authorizationStatus: .authorized))) {
      $0.userNotificationSettings = .init(authorizationStatus: .authorized)
    }
    await store.receive(.fetchTodaysDailyChallengeResponse(.success([.played]))) {
      $0.dailyChallenges = [.played]
    }
  }

  func testTapGameThatWasPlayed() async {
    var dailyChallengeResponse = FetchTodaysDailyChallengeResponse.played
    dailyChallengeResponse.dailyChallenge.endsAt = Date().addingTimeInterval(60 * 60 * 2 + 1)

    let store = TestStore(
      initialState: DailyChallengeReducer.State(dailyChallenges: [dailyChallengeResponse]),
      reducer: DailyChallengeReducer()
    )

    await store.send(.gameButtonTapped(.unlimited)) {
      $0.alert = .init(
        title: .init("Already played"),
        message: .init(
          "You already played today’s daily challenge. You can play the next one in in 2 hours."
        ),
        dismissButton: .default(.init("OK"), action: .send(.dismissAlert))
      )
    }
  }

  func testTapGameThatWasNotStarted() async {
    var inProgressGame = InProgressGame.mock
    inProgressGame.gameStartTime = self.mainRunLoop.now.date
    inProgressGame.gameContext = .dailyChallenge(.init(rawValue: .dailyChallengeId))

    let store = TestStore(
      initialState: DailyChallengeReducer.State(dailyChallenges: [.notStarted]),
      reducer: DailyChallengeReducer()
    )

    store.dependencies.mainRunLoop = self.mainRunLoop.eraseToAnyScheduler()
    store.dependencies.apiClient.override(
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
    struct FileNotFound: Error {}
    store.dependencies.persistenceClient.load = { @Sendable _ in throw FileNotFound() }

    await store.send(.gameButtonTapped(.unlimited)) {
      $0.gameModeIsLoading = .unlimited
    }

    await self.mainRunLoop.advance()
    await store.receive(.startDailyChallengeResponse(.success(inProgressGame))) {
      $0.gameModeIsLoading = nil
    }
    await store.receive(.delegate(.startGame(inProgressGame)))
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
      ),
      reducer: DailyChallengeReducer()
    )

    store.dependencies.persistenceClient.load = { @Sendable [inProgressGame] _ in
      try JSONEncoder().encode(SavedGamesState(dailyChallengeUnlimited: inProgressGame))
    }
    store.dependencies.mainRunLoop = .immediate

    await store.send(.gameButtonTapped(.unlimited)) {
      $0.gameModeIsLoading = .unlimited
    }

    await store.receive(.startDailyChallengeResponse(.success(inProgressGame))) {
      $0.gameModeIsLoading = nil
    }
    await store.receive(.delegate(.startGame(inProgressGame)))
  }

  func testNotifications_OpenThenClose() async {
    let store = TestStore(
      initialState: DailyChallengeReducer.State(),
      reducer: DailyChallengeReducer()
    )

    await store.send(.notificationButtonTapped) {
      $0.notificationsAuthAlert = .init()
    }
    await store.send(.notificationsAuthAlert(.closeButtonTapped))
    await store.receive(.notificationsAuthAlert(.delegate(.close))) {
      $0.notificationsAuthAlert = nil
    }
  }

  func testNotifications_GrantAccess() async {
    let didRegisterForRemoteNotifications = ActorIsolated(false)

    let store = TestStore(
      initialState: DailyChallengeReducer.State(),
      reducer: DailyChallengeReducer()
    )

    store.dependencies.userNotifications.getNotificationSettings = {
      .init(authorizationStatus: .authorized)
    }
    store.dependencies.userNotifications.requestAuthorization = { _ in true }
    store.dependencies.remoteNotifications.register = {
      await didRegisterForRemoteNotifications.setValue(true)
    }
    store.dependencies.mainRunLoop = .immediate

    await store.send(.notificationButtonTapped) {
      $0.notificationsAuthAlert = .init()
    }
    await store.send(.notificationsAuthAlert(.turnOnNotificationsButtonTapped))
    await store.receive(
      .notificationsAuthAlert(
        .delegate(.didChooseNotificationSettings(.init(authorizationStatus: .authorized)))
      )
    ) {
      $0.notificationsAuthAlert = nil
      $0.userNotificationSettings = .init(authorizationStatus: .authorized)
    }

    await didRegisterForRemoteNotifications.withValue { XCTAssertNoDifference($0, true) }
  }

  func testNotifications_DenyAccess() async {
    let store = TestStore(
      initialState: DailyChallengeReducer.State(),
      reducer: DailyChallengeReducer()
    )

    store.dependencies.userNotifications.getNotificationSettings = {
      .init(authorizationStatus: .denied)
    }
    store.dependencies.userNotifications.requestAuthorization = { _ in false }
    store.dependencies.mainRunLoop = .immediate

    await store.send(.notificationButtonTapped) {
      $0.notificationsAuthAlert = .init()
    }
    await store.send(.notificationsAuthAlert(.turnOnNotificationsButtonTapped))
    await store.receive(
      .notificationsAuthAlert(
        .delegate(.didChooseNotificationSettings(.init(authorizationStatus: .denied)))
      )
    ) {
      $0.notificationsAuthAlert = nil
      $0.userNotificationSettings = .init(authorizationStatus: .denied)
    }
  }
}
