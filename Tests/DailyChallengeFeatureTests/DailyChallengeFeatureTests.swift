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
    var environment = DailyChallengeEnvironment.failing
    environment.apiClient.override(
      route: .dailyChallenge(.today(language: .en)),
      withResponse: .ok([FetchTodaysDailyChallengeResponse.played])
    )
    environment.mainRunLoop = .immediate
    environment.userNotifications.getNotificationSettingsAsync = {
      .init(authorizationStatus: .authorized)
    }

    let store = TestStore(
      initialState: .init(),
      reducer: dailyChallengeReducer,
      environment: environment
    )

    await store.send(.onAppear)

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
      initialState: DailyChallengeState(dailyChallenges: [dailyChallengeResponse]),
      reducer: dailyChallengeReducer,
      environment: .failing
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

    var environment = DailyChallengeEnvironment.failing
    environment.mainRunLoop = self.mainRunLoop.eraseToAnyScheduler()
    environment.apiClient.override(
      route: .dailyChallenge(.start(gameMode: .unlimited, language: .en)),
      withResponse: .ok(
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
    )
    struct FileNotFound: Error {}
    environment.fileClient.load = { _ in .init(error: FileNotFound()) }

    let store = TestStore(
      initialState: DailyChallengeState(dailyChallenges: [.notStarted]),
      reducer: dailyChallengeReducer,
      environment: environment
    )

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

    var environment = DailyChallengeEnvironment.failing
    environment.fileClient.load = { asdf in
      .init(
        value: try! JSONEncoder().encode(
          SavedGamesState.init(dailyChallengeUnlimited: inProgressGame)
        )
      )
    }
    environment.mainRunLoop = .immediate

    let store = TestStore(
      initialState: DailyChallengeState(
        dailyChallenges: [.started],
        inProgressDailyChallengeUnlimited: inProgressGame
      ),
      reducer: dailyChallengeReducer,
      environment: environment
    )

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
      initialState: DailyChallengeState(),
      reducer: dailyChallengeReducer,
      environment: .failing
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
    var didRegisterForRemoteNotifications = false

    var environment = DailyChallengeEnvironment.failing
    environment.userNotifications.getNotificationSettings = .init(
      value: .init(authorizationStatus: .authorized)
    )
    environment.userNotifications.requestAuthorization = { options in
      .init(value: true)
    }
    environment.remoteNotifications.register = {
      .fireAndForget {
        didRegisterForRemoteNotifications = true
      }
    }
    environment.mainRunLoop = .immediate

    let store = TestStore(
      initialState: DailyChallengeState(),
      reducer: dailyChallengeReducer,
      environment: environment
    )

    await store.send(.notificationButtonTapped) {
      $0.notificationsAuthAlert = .init()
    }
    await store.send(.notificationsAuthAlert(.turnOnNotificationsButtonTapped))
    await store.receive(
      .notificationsAuthAlert(
        .delegate(
          .didChooseNotificationSettings(.init(authorizationStatus: .authorized))
        )
      )
    ) {
      $0.notificationsAuthAlert = nil
      $0.userNotificationSettings = .init(authorizationStatus: .authorized)
    }

    XCTAssertNoDifference(didRegisterForRemoteNotifications, true)
  }

  func testNotifications_DenyAccess() async {
    var environment = DailyChallengeEnvironment.failing
    environment.userNotifications.getNotificationSettings = .init(
      value: .init(authorizationStatus: .denied)
    )
    environment.userNotifications.requestAuthorization = { options in
      .init(value: false)
    }
    environment.mainRunLoop = .immediate

    let store = TestStore(
      initialState: DailyChallengeState(),
      reducer: dailyChallengeReducer,
      environment: environment
    )

    await store.send(.notificationButtonTapped) {
      $0.notificationsAuthAlert = .init()
    }
    await store.send(.notificationsAuthAlert(.turnOnNotificationsButtonTapped))
    await store.receive(
      .notificationsAuthAlert(
        .delegate(
          .didChooseNotificationSettings(.init(authorizationStatus: .denied))
        )
      )
    ) {
      $0.notificationsAuthAlert = nil
      $0.userNotificationSettings = .init(authorizationStatus: .denied)
    }
  }
}

extension DailyChallengeEnvironment {
  static let failing = Self(
    apiClient: .failing,
    fileClient: .failing,
    mainQueue: .failing,
    mainRunLoop: .failing,
    remoteNotifications: .failing,
    userNotifications: .failing
  )
}
