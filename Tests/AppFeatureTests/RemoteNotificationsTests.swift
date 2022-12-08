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
    let store = TestStore(
      initialState: AppReducer.State(),
      reducer: AppReducer()
    )

    let didRegisterForRemoteNotifications = ActorIsolated(false)
    let requestedAuthorizationOptions = ActorIsolated<UNAuthorizationOptions?>(nil)

    store.dependencies.didFinishLaunching()
    store.dependencies.build.number = { 80 }
    store.dependencies.remoteNotifications.register = {
      await didRegisterForRemoteNotifications.setValue(true)
    }
    store.dependencies.userNotifications.getNotificationSettings = {
      .init(authorizationStatus: .authorized)
    }
    store.dependencies.userNotifications.requestAuthorization = { options in
      await requestedAuthorizationOptions.setValue(options)
      return true
    }

    // Register remote notifications on .didFinishLaunching

    let task = await store.send(.appDelegate(.didFinishLaunching))
    await requestedAuthorizationOptions.withValue { XCTAssertNoDifference($0, [.alert, .sound]) }
    await didRegisterForRemoteNotifications.withValue { XCTAssertTrue($0) }

    store.dependencies.apiClient.override(
      route: .push(
        .register(.init(authorizationStatus: .authorized, build: 80, token: "6465616462656566"))
      ),
      withResponse: { (Data(), URLResponse()) }
    )
    await store.send(
      .appDelegate(.didRegisterForRemoteNotifications(.success(Data("deadbeef".utf8)))))

    // Register remote notifications on .didChangeScenePhase(.active)

    await didRegisterForRemoteNotifications.setValue(false)

    await store.send(.didChangeScenePhase(.active))
    await didRegisterForRemoteNotifications.withValue { XCTAssertTrue($0) }

    store.dependencies.apiClient.override(
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
    let didRegisterForRemoteNotifications = ActorIsolated(false)
    let requestedAuthorizationOptions = ActorIsolated<UNAuthorizationOptions?>(nil)

    let store = TestStore(
      initialState: AppReducer.State(),
      reducer: AppReducer()
    )

    store.dependencies.didFinishLaunching()
    store.dependencies.remoteNotifications.register = {
      await didRegisterForRemoteNotifications.setValue(true)
    }
    store.dependencies.userNotifications.getNotificationSettings = {
      .init(authorizationStatus: .notDetermined)
    }
    store.dependencies.userNotifications.requestAuthorization = { options in
      await requestedAuthorizationOptions.setValue(options)
      return true
    }

    let task = await store.send(.appDelegate(.didFinishLaunching))
    await store.send(.didChangeScenePhase(.active))

    await task.cancel()
  }

  func testReceiveNotification_dailyChallengeEndsSoon() async {
    let inProgressGame = InProgressGame.mock

    let store = TestStore(
      initialState: update(AppReducer.State()) {
        $0.home.savedGames.dailyChallengeUnlimited = inProgressGame
      },
      reducer: AppReducer()
    )

    store.dependencies.didFinishLaunching()
//    store.dependencies.fileClient.save = { @Sendable _, _ in }
    store.dependencies.userSettingsClient.save = { @Sendable _, _ in }

    let delegate = AsyncStream<UserNotificationClient.DelegateEvent>.streamWithContinuation()
    store.dependencies.userNotifications.delegate = { delegate.stream }

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
      $0.game = Game.State(inProgressGame: inProgressGame)
      $0.home.savedGames.unlimited = inProgressGame
    }
    XCTAssert(didReceiveResponseCompletionHandlerCalled)

    await task.cancel()
  }
}
