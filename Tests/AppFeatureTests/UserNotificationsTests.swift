import Combine
import ComposableArchitecture
import ComposableUserNotifications
import CustomDump
import Dependencies
import Overture
import UserNotifications
import XCTest

@testable import AppFeature

@MainActor
class UserNotificationsTests: XCTestCase {
  func testReceiveBackgroundNotification() async {
    let delegate = AsyncStream<UserNotificationClient.DelegateEvent>.makeStream()
    let response = UserNotificationClient.Notification.Response(
      notification: UserNotificationClient.Notification(
        date: .mock,
        request: UNNotificationRequest(
          identifier: "deadbeef",
          content: UNNotificationContent(),
          trigger: nil
        )
      )
    )
    let didCallback = LockIsolated(false)

    let store = withDependencies {
      $0.didFinishLaunching()
      $0.userNotifications.delegate = { delegate.stream }
    } operation: {
      TestStore(initialState: AppReducer.State()) {
        AppReducer()
      }
    }

    delegate.continuation.yield(
      .didReceiveResponse(response, completionHandler: { didCallback.setValue(true) })
    )

    delegate.continuation.finish()
    await store.mountTask?.value
    XCTAssertTrue(didCallback.value)

    await store.dismount()
  }

  func testReceiveForegroundNotification() async {
    let delegate = AsyncStream<UserNotificationClient.DelegateEvent>.makeStream()
    let notification = UserNotificationClient.Notification(
      date: .mock,
      request: UNNotificationRequest(
        identifier: "deadbeef",
        content: UNNotificationContent(),
        trigger: nil
      )
    )
    let didCallbackWithOptions = LockIsolated<UNNotificationPresentationOptions?>(nil)

    let store = withDependencies {
      $0.didFinishLaunching()
      $0.userNotifications.delegate = { delegate.stream }
    } operation: {
      TestStore(initialState: AppReducer.State()) {
        AppReducer()
      }
    }

    delegate.continuation.yield(
      .willPresentNotification(
        notification,
        completionHandler: { didCallbackWithOptions.setValue($0) }
      )
    )
    delegate.continuation.finish()
    await store.mountTask?.value

    expectNoDifference(didCallbackWithOptions.value, .banner)

    await store.dismount()
  }
}
