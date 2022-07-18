import ClientModels
import Combine
import ComposableArchitecture
import ComposableUserNotifications
import GameFeature
import Overture
import UserNotifications
import XCTest

@testable import AppFeature

@MainActor
class RemoteNotificationsTests: XCTestCase {
  func testRegisterForRemoteNotifications_OnActivate_Authorized() async {
    let didRegisterForRemoteNotifications = SendableState(false)
    let requestedAuthorizationOptions: SendableState<UNAuthorizationOptions?> = .init()

    var environment = AppEnvironment.didFinishLaunching
    environment.build.number = { 80 }
    environment.remoteNotifications.register = {
      await didRegisterForRemoteNotifications.set(true)
    }
    environment.userNotifications.getNotificationSettings = {
      .init(authorizationStatus: .authorized)
    }
    environment.userNotifications.requestAuthorization = { options in
      await requestedAuthorizationOptions.set(options)
      return true
    }

    let store = TestStore(
      initialState: AppState(),
      reducer: appReducer,
      environment: environment
    )

    // Register remote notifications on .didFinishLaunching

    let task = await store.send(.appDelegate(.didFinishLaunching))
    await requestedAuthorizationOptions.modify { XCTAssertNoDifference($0, [.alert, .sound]) }
    await didRegisterForRemoteNotifications.modify { XCTAssertTrue($0) }

    store.environment.apiClient.override(
      route: .push(
        .register(.init(authorizationStatus: .authorized, build: 80, token: "6465616462656566"))
      ),
      withResponse: { (Data(), URLResponse()) }
    )
    await store.send(
      .appDelegate(.didRegisterForRemoteNotifications(.success(Data("deadbeef".utf8)))))

    // Register remote notifications on .didChangeScenePhase(.active)

    await didRegisterForRemoteNotifications.set(false)

    await store.send(.didChangeScenePhase(.active))
    await didRegisterForRemoteNotifications.modify { XCTAssertTrue($0) }

    store.environment.apiClient.override(
      route: .push(
        .register(.init(authorizationStatus: .authorized, build: 80, token: "6261616462656566"))
      ),
      withResponse: { (Data(), URLResponse()) }
    )
    await store.send(
      .appDelegate(.didRegisterForRemoteNotifications(.success(Data("baadbeef".utf8)))))

    await task.cancel()
  }

  func testRegisterForRemoteNotifications_NotAuthorized() async {
    var environment = AppEnvironment.didFinishLaunching
    environment.remoteNotifications = .failing

    let store = TestStore(
      initialState: AppState(),
      reducer: appReducer,
      environment: environment
    )

    let task = await store.send(.appDelegate(.didFinishLaunching))
    await store.send(.didChangeScenePhase(.active))
    await task.cancel()
  }

  func testReceiveNotification_dailyChallengeEndsSoon() async {
    let delegate = AsyncStream<UserNotificationClient.DelegateEvent>.streamWithContinuation()

    var environment = AppEnvironment.didFinishLaunching
    environment.fileClient.save = { @Sendable _, _ in }
    environment.userNotifications.delegate = { delegate.stream }

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

    let task = await store.send(.appDelegate(.didFinishLaunching))

    delegate.continuation.yield(
      .willPresentNotification(
        notification,
        completionHandler: { willPresentNotificationCompletionHandler($0) }
      )
    )
    await store.receive(
      .appDelegate(
        .userNotifications(
          .willPresentNotification(
            notification,
            completionHandler: { willPresentNotificationCompletionHandler($0) }
          )
        )
      )
    )
    XCTAssertNoDifference(notificationPresentationOptions, .banner)

    delegate.continuation.yield(
      .didReceiveResponse(response, completionHandler: { didReceiveResponseCompletionHandler() })
    )
    await store.receive(
      .appDelegate(
        .userNotifications(
          .didReceiveResponse(
            response,
            completionHandler: { didReceiveResponseCompletionHandler() }
          )
        )
      )
    ) {
      $0.game = GameState(inProgressGame: inProgressGame)
      $0.home.savedGames.unlimited = inProgressGame
    }
    XCTAssert(didReceiveResponseCompletionHandlerCalled)

    await task.cancel()
  }
}
