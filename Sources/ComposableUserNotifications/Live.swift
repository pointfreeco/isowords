import Combine
import ComposableArchitecture
import UserNotifications

extension UserNotificationClient {
  public static let live = Self(
    add: { request in
      try await UNUserNotificationCenter.current().add(request)
    },
    delegate:
      Effect
      .run { subscriber in
        var delegate: Optional = Delegate(subscriber: subscriber)
        UNUserNotificationCenter.current().delegate = delegate
        return AnyCancellable {
          delegate = nil
        }
      }
      .share()
      .eraseToEffect(),
    getNotificationSettings: {
      await withUnsafeContinuation { continuation in
        UNUserNotificationCenter.current().getNotificationSettings { settings in
          continuation.resume(returning: .init(rawValue: settings))
        }
      }
    },
    removeDeliveredNotificationsWithIdentifiers: { identifiers in
      UNUserNotificationCenter.current()
        .removeDeliveredNotifications(withIdentifiers: identifiers)
    },
    removePendingNotificationRequestsWithIdentifiers: { identifiers in
      UNUserNotificationCenter.current()
        .removePendingNotificationRequests(withIdentifiers: identifiers)
    },
    requestAuthorization: { options in
      try await UNUserNotificationCenter.current().requestAuthorization(options: options)
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
    let subscriber: Effect<UserNotificationClient.DelegateEvent, Never>.Subscriber

    init(subscriber: Effect<UserNotificationClient.DelegateEvent, Never>.Subscriber) {
      self.subscriber = subscriber
    }

    func userNotificationCenter(
      _ center: UNUserNotificationCenter,
      didReceive response: UNNotificationResponse,
      withCompletionHandler completionHandler: @escaping () -> Void
    ) {
      self.subscriber.send(
        .didReceiveResponse(.init(rawValue: response), completionHandler: completionHandler)
      )
    }

    func userNotificationCenter(
      _ center: UNUserNotificationCenter,
      openSettingsFor notification: UNNotification?
    ) {
      self.subscriber.send(
        .openSettingsForNotification(notification.map(Notification.init(rawValue:)))
      )
    }

    func userNotificationCenter(
      _ center: UNUserNotificationCenter,
      willPresent notification: UNNotification,
      withCompletionHandler completionHandler:
        @escaping (UNNotificationPresentationOptions) -> Void
    ) {
      self.subscriber.send(
        .willPresentNotification(
          .init(rawValue: notification),
          completionHandler: completionHandler
        )
      )
    }
  }
}
