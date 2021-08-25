import ClientModels
import Combine
import ComposableArchitecture
import ComposableUserNotifications
import GameFeature
import Overture
import UserNotifications
import XCTest

@testable import AppFeature

class RemoteNotificationsTests: XCTestCase {
  func testRegisterForRemoteNotifications_OnActivate_Authorized() {
    var didRegisterForRemoteNotifications = false
    var requestedAuthorizationOptions: UNAuthorizationOptions?

    var environment = AppEnvironment.didFinishLaunching
    environment.build.number = { 80 }
    environment.remoteNotifications.register = {
      .fireAndForget {
        didRegisterForRemoteNotifications = true
      }
    }
    environment.userNotifications.getNotificationSettings = .init(
      value: .init(authorizationStatus: .authorized)
    )
    environment.userNotifications.requestAuthorization = { options in
      requestedAuthorizationOptions = options
      return .init(value: true)
    }

    let store = TestStore(
      initialState: AppState(),
      reducer: appReducer,
      environment: environment
    )

    // Register remote notifications on .didFinishLaunching

    store.send(.appDelegate(.didFinishLaunching))
    XCTAssertNoDifference(requestedAuthorizationOptions, [.alert, .sound])
    XCTAssertTrue(didRegisterForRemoteNotifications)

    store.environment.apiClient.override(
      route: .push(
        .register(.init(authorizationStatus: .authorized, build: 80, token: "6465616462656566"))
      ),
      withResponse: .init(value: (Data(), URLResponse()))
    )
    store.send(.appDelegate(.didRegisterForRemoteNotifications(.success(Data("deadbeef".utf8)))))

    // Register remote notifications on .didChangeScenePhase(.active)

    didRegisterForRemoteNotifications = false

    store.environment.audioPlayer.secondaryAudioShouldBeSilencedHint = { false }
    store.environment.audioPlayer.setGlobalVolumeForMusic = { _ in .none }

    store.send(.didChangeScenePhase(.active))
    XCTAssertTrue(didRegisterForRemoteNotifications)

    store.environment.apiClient.override(
      route: .push(
        .register(.init(authorizationStatus: .authorized, build: 80, token: "6261616462656566"))
      ),
      withResponse: .init(value: (Data(), URLResponse()))
    )
    store.send(.appDelegate(.didRegisterForRemoteNotifications(.success(Data("baadbeef".utf8)))))
  }

  func testRegisterForRemoteNotifications_NotAuthorized() {
    var environment = AppEnvironment.didFinishLaunching
    environment.remoteNotifications = .failing

    let store = TestStore(
      initialState: AppState(),
      reducer: appReducer,
      environment: environment
    )

    store.send(.appDelegate(.didFinishLaunching))

    store.environment.audioPlayer.secondaryAudioShouldBeSilencedHint = { false }
    store.environment.audioPlayer.setGlobalVolumeForMusic = { _ in .none }

    store.send(.didChangeScenePhase(.active))
  }

  func testReceiveNotification_dailyChallengeEndsSoon() {
    let userNotificationsDelegate = PassthroughSubject<
      UserNotificationClient.DelegateEvent, Never
    >()

    var environment = AppEnvironment.didFinishLaunching
    environment.fileClient.save = { _, _ in .none }
    environment.userNotifications.delegate = userNotificationsDelegate.eraseToEffect()

    let inProgressGame = InProgressGame.mock

    let store = TestStore(
      initialState: update(AppState()) {
        $0.home.savedGames.dailyChallengeUnlimited = inProgressGame
      },
      reducer: appReducer,
      environment: environment
    )

    let notification = UserNotificationClient.Notification(
      date: .mock,
      request: .init(
        identifier: "deadbeef",
        content: updateObject(UNMutableNotificationContent()) {
          $0.userInfo = [
            "dailyChallengeEndsSoon": true
          ]
        },
        trigger: nil
      )
    )
    let response = UserNotificationClient.Notification.Response(notification: notification)

    var notificationPresentationOptions: UNNotificationPresentationOptions?
    let willPresentNotificationCompletionHandler = { notificationPresentationOptions = $0 }

    var didReceiveResponseCompletionHandlerCalled = false
    let didReceiveResponseCompletionHandler = { didReceiveResponseCompletionHandlerCalled = true }

    store.send(.appDelegate(.didFinishLaunching))

    userNotificationsDelegate.send(
      .willPresentNotification(
        notification,
        completionHandler: willPresentNotificationCompletionHandler
      )
    )

    store.receive(
      .appDelegate(
        .userNotifications(
          .willPresentNotification(
            notification,
            completionHandler: willPresentNotificationCompletionHandler
          )
        )
      )
    )
    XCTAssertNoDifference(notificationPresentationOptions, .banner)

    userNotificationsDelegate.send(
      .didReceiveResponse(response, completionHandler: didReceiveResponseCompletionHandler)
    )

    store.receive(
      .appDelegate(
        .userNotifications(
          .didReceiveResponse(
            response,
            completionHandler: didReceiveResponseCompletionHandler
          )
        )
      )
    ) {
      $0.game = GameState(inProgressGame: inProgressGame)
      $0.home.savedGames.unlimited = inProgressGame
    }
    XCTAssert(didReceiveResponseCompletionHandlerCalled)

    userNotificationsDelegate.send(completion: .finished)
  }
}
