import ClientModels
import Combine
import ComposableArchitecture
import ComposableUserNotifications
import GameCore
import Overture
import UserNotifications
import XCTest

@testable import AppFeature

class RemoteNotificationsTests: XCTestCase {
  @MainActor
  func testRegisterForRemoteNotifications_OnActivate_Authorized() async {
    let didRegisterForRemoteNotifications = ActorIsolated(false)
    let requestedAuthorizationOptions = ActorIsolated<UNAuthorizationOptions?>(nil)

    let store = TestStore(
      initialState: AppReducer.State()
    ) {
      AppReducer()
    } withDependencies: {
      $0.didFinishLaunching()
      $0.build.number = { 80 }
      $0.remoteNotifications.register = {
        await didRegisterForRemoteNotifications.setValue(true)
      }
      $0.userNotifications.getNotificationSettings = {
        .init(authorizationStatus: .authorized)
      }
      $0.userNotifications.requestAuthorization = { options in
        await requestedAuthorizationOptions.setValue(options)
        return true
      }
    }

    // Register remote notifications on .didFinishLaunching

    let task = await store.send(.appDelegate(.didFinishLaunching))
    await requestedAuthorizationOptions.withValue { expectNoDifference($0, [.alert, .sound]) }
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

  @MainActor
  func testRegisterForRemoteNotifications_NotAuthorized() async {
    let didRegisterForRemoteNotifications = ActorIsolated(false)
    let requestedAuthorizationOptions = ActorIsolated<UNAuthorizationOptions?>(nil)

    let store = TestStore(initialState: AppReducer.State()) {
      AppReducer()
    } withDependencies: {
      $0.didFinishLaunching()
      $0.remoteNotifications.register = {
        await didRegisterForRemoteNotifications.setValue(true)
      }
      $0.userNotifications.getNotificationSettings = {
        .init(authorizationStatus: .notDetermined)
      }
      $0.userNotifications.requestAuthorization = { options in
        await requestedAuthorizationOptions.setValue(options)
        return true
      }
    }

    let task = await store.send(.appDelegate(.didFinishLaunching))
    await store.send(.didChangeScenePhase(.active))

    await task.cancel()
  }

  @MainActor
  func testReceiveNotification_dailyChallengeEndsSoon() async {
    let inProgressGame = InProgressGame.mock

    let store = TestStore(
      initialState: update(AppReducer.State()) {
        $0.home.savedGames.dailyChallengeUnlimited = .mock
      }
    ) {
      AppReducer()
    } withDependencies: {
      $0.didFinishLaunching()
      $0.fileClient.save = { @Sendable _, _ in }
    }

    let delegate = AsyncStream<UserNotificationClient.DelegateEvent>.makeStream()
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
    await store.receive(\.appDelegate.userNotifications.willPresentNotification)
    expectNoDifference(notificationPresentationOptions, .banner)

    delegate.continuation.yield(
      .didReceiveResponse(response, completionHandler: { didReceiveResponseCompletionHandler() })
    )
    await store.receive(\.appDelegate.userNotifications.didReceiveResponse) {
      $0.destination = .game(Game.State(inProgressGame: inProgressGame))
      $0.home.savedGames.unlimited = inProgressGame
    }
    XCTAssert(didReceiveResponseCompletionHandlerCalled)

    await task.cancel()
  }
}
