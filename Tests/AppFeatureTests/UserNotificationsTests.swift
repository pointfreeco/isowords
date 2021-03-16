import Combine
import ComposableArchitecture
import ComposableUserNotifications
import Overture
import UserNotifications
import XCTest

@testable import AppFeature

class UserNotificationsTests: XCTestCase {
  func testReceiveBackgroundNotification() {
    let delegate = PassthroughSubject<UserNotificationClient.DelegateEvent, Never>()
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
        $0.userNotifications.delegate = delegate.eraseToEffect()
      }
    )

    store.send(.appDelegate(.didFinishLaunching))

    delegate.send(.didReceiveResponse(response, completionHandler: completionHandler))

    store.receive(
      .appDelegate(
        .userNotifications(
          .didReceiveResponse(response, completionHandler: completionHandler)
        )
      )
    ) { _ in
      XCTAssertTrue(didCallback)

      delegate.send(completion: .finished)
    }
  }

  func testReceiveForegroundNotification() {
    let delegate = PassthroughSubject<UserNotificationClient.DelegateEvent, Never>()
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
        $0.userNotifications.delegate = delegate.eraseToEffect()
      }
    )

    store.send(.appDelegate(.didFinishLaunching))

    delegate.send(.willPresentNotification(notification, completionHandler: completionHandler))

    store.receive(
      .appDelegate(
        .userNotifications(
          .willPresentNotification(notification, completionHandler: completionHandler)
        )
      )
    ) { _ in
      XCTAssertEqual(didCallbackWithOptions, .banner)

      delegate.send(completion: .finished)
    }
  }
}
