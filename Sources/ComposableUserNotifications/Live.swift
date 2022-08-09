import Combine
import ComposableArchitecture
import UserNotifications

extension UserNotificationClient {
  public static let live = Self(
    add: { try await UNUserNotificationCenter.current().add($0) },
    delegate: {
      AsyncStream { continuation in
        let delegate = Delegate(continuation: continuation)
        UNUserNotificationCenter.current().delegate = delegate
        continuation.onTermination = { [delegate] _ in }
      }
    },
    getNotificationSettings: {
      await Notification.Settings(
        rawValue: UNUserNotificationCenter.current().notificationSettings()
      )
    },
    removeDeliveredNotificationsWithIdentifiers: {
      UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: $0)
    },
    removePendingNotificationRequestsWithIdentifiers: {
      UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: $0)
    },
    requestAuthorization: {
      try await UNUserNotificationCenter.current().requestAuthorization(options: $0)
    }
  )
}

extension UserNotificationClient.Notification {
  public init(rawValue: UNNotification) {
    self.date = rawValue.date
    self.request = rawValue.request
  }
}

extension UserNotificationClient.Notification.Response {
  public init(rawValue: UNNotificationResponse) {
    self.notification = .init(rawValue: rawValue.notification)
  }
}

extension UserNotificationClient.Notification.Settings {
  public init(rawValue: UNNotificationSettings) {
    self.authorizationStatus = rawValue.authorizationStatus
  }
}

extension UserNotificationClient {
  fileprivate class Delegate: NSObject, UNUserNotificationCenterDelegate {
    let continuation: AsyncStream<UserNotificationClient.DelegateEvent>.Continuation

    init(continuation: AsyncStream<UserNotificationClient.DelegateEvent>.Continuation) {
      self.continuation = continuation
    }

    func userNotificationCenter(
      _ center: UNUserNotificationCenter,
      didReceive response: UNNotificationResponse,
      withCompletionHandler completionHandler: @escaping () -> Void
    ) {
      self.continuation.yield(
        .didReceiveResponse(.init(rawValue: response)) { completionHandler() }
      )
    }

    func userNotificationCenter(
      _ center: UNUserNotificationCenter,
      openSettingsFor notification: UNNotification?
    ) {
      self.continuation.yield(
        .openSettingsForNotification(notification.map(Notification.init(rawValue:)))
      )
    }

    func userNotificationCenter(
      _ center: UNUserNotificationCenter,
      willPresent notification: UNNotification,
      withCompletionHandler completionHandler:
        @escaping (UNNotificationPresentationOptions) -> Void
    ) {
      self.continuation.yield(
        .willPresentNotification(.init(rawValue: notification)) { completionHandler($0) }
      )
    }
  }
}
