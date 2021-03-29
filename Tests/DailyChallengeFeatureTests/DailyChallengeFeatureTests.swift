import ClientModels
import ComposableArchitecture
import XCTest

@testable import DailyChallengeFeature
@testable import SharedModels

class DailyChallengeFeatureTests: XCTestCase {
  let mainQueue = DispatchQueue.test
  let mainRunLoop = RunLoop.test

  func testOnAppear() {
    var environment = DailyChallengeEnvironment.failing
    environment.apiClient.override(
      route: .dailyChallenge(.today(language: .en)),
      withResponse: .ok([FetchTodaysDailyChallengeResponse.played])
    )
    environment.mainRunLoop = RunLoop.immediateScheduler.eraseToAnyScheduler()
    environment.userNotifications.getNotificationSettings = .init(
      value: .init(authorizationStatus: .authorized)
    )

    let store = TestStore(
      initialState: .init(),
      reducer: dailyChallengeReducer,
      environment: environment
    )

    store.send(.onAppear)

    store.receive(.fetchTodaysDailyChallengeResponse(.success([.played]))) {
      $0.dailyChallenges = [.played]
    }

    store.receive(.userNotificationSettingsResponse(.init(authorizationStatus: .authorized))) {
      $0.userNotificationSettings = .init(authorizationStatus: .authorized)
    }
  }

  func testTapGameThatWasPlayed() {
    var dailyChallengeResponse = FetchTodaysDailyChallengeResponse.played
    dailyChallengeResponse.dailyChallenge.endsAt = Date().addingTimeInterval(60 * 60 * 2 + 1)

    let store = TestStore(
      initialState: DailyChallengeState(dailyChallenges: [dailyChallengeResponse]),
      reducer: dailyChallengeReducer,
      environment: .failing
    )

    store.send(.gameButtonTapped(.unlimited)) {
      $0.alert = .init(
        title: .init("Already played"),
        message: .init(
          "You already played today’s daily challenge. You can play the next one in in 2 hours."
        ),
        primaryButton: .default(.init("OK"), send: .dismissAlert),
        secondaryButton: nil
      )
    }
  }

  func testTapGameThatWasNotStarted() {
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

    store.send(.gameButtonTapped(.unlimited)) {
      $0.gameModeIsLoading = .unlimited
    }

    self.mainRunLoop.advance()
    store.receive(.startDailyChallengeResponse(.success(inProgressGame))) {
      $0.gameModeIsLoading = nil
    }
    store.receive(.delegate(.startGame(inProgressGame)))
  }

  func testTapGameThatWasStarted_NotPlayed_HasLocalGame() {
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

    let store = TestStore(
      initialState: DailyChallengeState(
        dailyChallenges: [.started],
        inProgressDailyChallengeUnlimited: inProgressGame
      ),
      reducer: dailyChallengeReducer,
      environment: environment
    )

    store.send(.gameButtonTapped(.unlimited)) {
      $0.gameModeIsLoading = .unlimited
    }

    store.receive(.startDailyChallengeResponse(.success(inProgressGame))) {
      $0.gameModeIsLoading = nil
    }
    store.receive(.delegate(.startGame(inProgressGame)))
  }

  func testNotifications_OpenThenClose() {
    let store = TestStore(
      initialState: DailyChallengeState(),
      reducer: dailyChallengeReducer,
      environment: .failing
    )

    store.send(.notificationButtonTapped) {
      $0.notificationsAuthAlert = .init()
    }
    store.send(.notificationsAuthAlert(.closeButtonTapped))
    store.receive(.notificationsAuthAlert(.delegate(.close))) {
      $0.notificationsAuthAlert = nil
    }
  }

  func testNotifications_GrantAccess() {
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
    environment.mainQueue = .immediate

    let store = TestStore(
      initialState: DailyChallengeState(),
      reducer: dailyChallengeReducer,
      environment: environment
    )

    store.send(.notificationButtonTapped) {
      $0.notificationsAuthAlert = .init()
    }
    store.send(.notificationsAuthAlert(.turnOnNotificationsButtonTapped))
    store.receive(
      .notificationsAuthAlert(
        .delegate(
          .didChooseNotificationSettings(.init(authorizationStatus: .authorized))
        )
      )
    ) {
      $0.notificationsAuthAlert = nil
      $0.userNotificationSettings = .init(authorizationStatus: .authorized)
    }

    XCTAssertEqual(didRegisterForRemoteNotifications, true)
  }

  func testNotifications_DenyAccess() {
    var environment = DailyChallengeEnvironment.failing
    environment.userNotifications.getNotificationSettings = .init(
      value: .init(authorizationStatus: .denied)
    )
    environment.userNotifications.requestAuthorization = { options in
      .init(value: false)
    }
    environment.mainQueue = .immediate

    let store = TestStore(
      initialState: DailyChallengeState(),
      reducer: dailyChallengeReducer,
      environment: environment
    )

    store.send(.notificationButtonTapped) {
      $0.notificationsAuthAlert = .init()
    }
    store.send(.notificationsAuthAlert(.turnOnNotificationsButtonTapped))
    store.receive(
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
