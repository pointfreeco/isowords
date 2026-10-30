import ClientModels
import ComposableArchitecture
import ComposableUserNotifications
import ConcurrencyExtras
import CustomDump
import Dependencies
import GameCore
import Overture
import UserNotifications
import XCTest

@testable import AppFeature

@MainActor
class RemoteNotificationsTests: XCTestCase {
  func testRegisterForRemoteNotifications_OnActivate_Authorized() async {
    let didRegisterForRemoteNotifications = LockIsolated(false)
    let requestedAuthorizationOptions = LockIsolated<UNAuthorizationOptions?>(nil)

    let store = withDependencies {
      $0.didFinishLaunching()
      $0.apiClient.override(
        route: .push(
          .register(.init(authorizationStatus: .authorized, build: 80, token: "6465616462656566"))
        ),
        withResponse: { (Data(), URLResponse()) }
      )
      $0.apiClient.override(
        route: .push(
          .register(.init(authorizationStatus: .authorized, build: 80, token: "6261616462656566"))
        ),
        withResponse: { (Data(), URLResponse()) }
      )
      $0.build.number = { 80 }
      $0.remoteNotifications.register = {
        didRegisterForRemoteNotifications.setValue(true)
      }
      $0.userNotifications.getNotificationSettings = {
        .init(authorizationStatus: .authorized)
      }
      $0.userNotifications.requestAuthorization = { options in
        requestedAuthorizationOptions.setValue(options)
        return true
      }
    } operation: {
      TestStore(initialState: AppReducer.State()) {
        AppReducer()
      }
    }


    await store.mountTask?.value
    expectNoDifference(requestedAuthorizationOptions.value, [.alert, .sound])
    XCTAssertTrue(didRegisterForRemoteNotifications.value)

    await store.send(
      .appDelegate(.didRegisterForRemoteNotifications(.success(Data("deadbeef".utf8))))
    )?.value

    // Register remote notifications on .didChangeScenePhase(.active)

    didRegisterForRemoteNotifications.setValue(false)

    await store.send(.didChangeScenePhase(.active))?.value
    XCTAssertTrue(didRegisterForRemoteNotifications.value)

    await store.send(
      .appDelegate(.didRegisterForRemoteNotifications(.success(Data("baadbeef".utf8))))
    )?.value

    await store.dismount()
  }

  func testRegisterForRemoteNotifications_NotAuthorized() async {
    let didRegisterForRemoteNotifications = LockIsolated(false)
    let requestedAuthorizationOptions = LockIsolated<UNAuthorizationOptions?>(nil)

    let store = withDependencies {
      $0.didFinishLaunching()
      $0.remoteNotifications.register = {
        didRegisterForRemoteNotifications.setValue(true)
      }
      $0.userNotifications.getNotificationSettings = {
        .init(authorizationStatus: .notDetermined)
      }
      $0.userNotifications.requestAuthorization = { options in
        requestedAuthorizationOptions.setValue(options)
        return true
      }
    } operation: {
      TestStore(initialState: AppReducer.State()) {
        AppReducer()
      }
    }

    await store.mountTask?.value
    expectNoDifference(requestedAuthorizationOptions.value, .provisional)
    XCTAssertTrue(didRegisterForRemoteNotifications.value)

    await store.send(.didChangeScenePhase(.active))?.value

    await store.dismount()
  }

  func testReceiveNotification_dailyChallengeEndsSoon() async {
    let inProgressGame = InProgressGame.mock
    let delegate = AsyncStream<UserNotificationClient.DelegateEvent>.makeStream()

    let store = withDependencies {
      $0.didFinishLaunching()
      $0.fileClient.save = { @Sendable _, _ in }
      $0.userNotifications.delegate = { delegate.stream }
    } operation: {
      TestStore(
        initialState: update(AppReducer.State()) {
          $0.home.savedGames.dailyChallengeUnlimited = .mock
        }
      ) {
        AppReducer()
          .environment(\.continuousClock, TestClock())
      }
    }

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

    let notificationPresentationOptions = LockIsolated<UNNotificationPresentationOptions?>(nil)
    let didReceiveResponseCompletionHandlerCalled = LockIsolated(false)

    delegate.continuation.yield(
      .willPresentNotification(
        notification,
        completionHandler: { notificationPresentationOptions.setValue($0) }
      )
    )
    delegate.continuation.yield(
      .didReceiveResponse(
        response,
        completionHandler: { didReceiveResponseCompletionHandlerCalled.setValue(true) }
      )
    )
    delegate.continuation.finish()
    await store.mountTask?.value
    store.expect {
      $0.destination = .game(
        snap(
          update(Game.State(inProgressGame: inProgressGame)) {
            $0.gameCurrentTime = Date(timeIntervalSinceReferenceDate: 0)
          }
        )
      )
      $0.home.activeGames.savedGames.unlimited = inProgressGame
    }
    expectNoDifference(notificationPresentationOptions.value, .banner)
    XCTAssert(didReceiveResponseCompletionHandlerCalled.value)

    await store.dismount()
  }
}
