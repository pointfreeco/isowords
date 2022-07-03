import Combine
import ComposableArchitecture
import UserNotifications

extension UserNotificationClient {
  public static let live = Self(
    add: { request in
      .future { callback in
        UNUserNotificationCenter.current().add(request) { error in
          if let error = error {
            callback(.failure(error))
          } else {
            callback(.success(()))
          }
        }
      }
    },
    addAsync: { try await UNUserNotificationCenter.current().add($0) },
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
    delegateAsync: {
      fatalError()
    },
    getNotificationSettings: .future { callback in
      UNUserNotificationCenter.current().getNotificationSettings { settings in
        callback(.success(.init(rawValue: settings)))
      }
    },
    getNotificationSettingsAsync: {
      await Notification.Settings(
        rawValue: UNUserNotificationCenter.current().notificationSettings()
      )
    },
    removeDeliveredNotificationsWithIdentifiers: { identifiers in
      .fireAndForget {
        UNUserNotificationCenter.current()
          .removeDeliveredNotifications(withIdentifiers: identifiers)
      }
    },
    removeDeliveredNotificationsWithIdentifiersAsync: {
      UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: $0)
    },
    removePendingNotificationRequestsWithIdentifiers: { identifiers in
      .fireAndForget {
        UNUserNotificationCenter.current()
          .removePendingNotificationRequests(withIdentifiers: identifiers)
      }
    },
    removePendingNotificationRequestsWithIdentifiersAsync: {
      UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: $0)
    },
    requestAuthorization: { options in
      .future { callback in
        UNUserNotificationCenter.current()
          .requestAuthorization(options: options) { granted, error in
            if let error = error {
              callback(.failure(error))
            } else {
              callback(.success(granted))
            }
          }
      }
    },
    requestAuthorizationAsync: {
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
