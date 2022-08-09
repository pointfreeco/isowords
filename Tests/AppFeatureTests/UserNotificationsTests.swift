import Combine
import ComposableArchitecture
import ComposableUserNotifications
import Overture
import UserNotifications
import XCTest

@testable import AppFeature

@MainActor
class UserNotificationsTests: XCTestCase {
  func testReceiveBackgroundNotification() async {
    let delegate = AsyncStream<UserNotificationClient.DelegateEvent>.streamWithContinuation()
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
    var didCallback = false
    let completionHandler = { didCallback = true }

    let store = TestStore(
      initialState: .init(),
      reducer: appReducer,
      environment: update(.didFinishLaunching) {
        $0.userNotifications.delegate = { delegate.stream }
      }
    )

    let task = await store.send(.appDelegate(.didFinishLaunching))

    delegate.continuation.yield(
      .didReceiveResponse(response, completionHandler: { completionHandler() })
    )

    await store.receive(
      .appDelegate(
        .userNotifications(
          .didReceiveResponse(response, completionHandler: { completionHandler() })
        )
      )
    )
    XCTAssertTrue(didCallback)

    await task.cancel()
  }

  func testReceiveForegroundNotification() async {
    let delegate = AsyncStream<UserNotificationClient.DelegateEvent>.streamWithContinuation()
    let notification = UserNotificationClient.Notification(
      date: .mock,
      request: UNNotificationRequest(
        identifier: "deadbeef",
        content: UNNotificationContent(),
        trigger: nil
      )
    )
    var didCallbackWithOptions: UNNotificationPresentationOptions?
    let completionHandler = { didCallbackWithOptions = $0 }

    let store = TestStore(
      initialState: .init(),
      reducer: appReducer,
      environment: update(.didFinishLaunching) {
        $0.userNotifications.delegate = { delegate.stream }
      }
    )

    let task = await store.send(.appDelegate(.didFinishLaunching))

    delegate.continuation.yield(
      .willPresentNotification(notification, completionHandler: { completionHandler($0) })
    )

    await store.receive(
      .appDelegate(
        .userNotifications(
          .willPresentNotification(notification, completionHandler: { completionHandler($0) })
        )
      )
    )

    XCTAssertNoDifference(didCallbackWithOptions, .banner)

    await task.cancel()
  }
}
