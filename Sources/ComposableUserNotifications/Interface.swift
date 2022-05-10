import Combine
import ComposableArchitecture
import UserNotifications

public struct UserNotificationClient {
  public var add: (UNNotificationRequest) async throws -> Void
  public var delegate: Effect<DelegateEvent, Never>
  public var getNotificationSettings: () async -> Notification.Settings
  public var removeDeliveredNotificationsWithIdentifiers: ([String]) async -> Void
  public var removePendingNotificationRequestsWithIdentifiers: ([String]) async -> Void
  public var requestAuthorization: (UNAuthorizationOptions) async throws -> Bool

  public enum DelegateEvent: Equatable {
    case didReceiveResponse(Notification.Response, completionHandler: () -> Void)
    case openSettingsForNotification(Notification?)
    case willPresentNotification(
      Notification, completionHandler: (UNNotificationPresentationOptions) -> Void)

    public static func == (lhs: Self, rhs: Self) -> Bool {
      switch (lhs, rhs) {
      case let (.didReceiveResponse(lhs, _), .didReceiveResponse(rhs, _)):
        return lhs == rhs
      case let (.openSettingsForNotification(lhs), .openSettingsForNotification(rhs)):
        return lhs == rhs
      case let (.willPresentNotification(lhs, _), .willPresentNotification(rhs, _)):
        return lhs == rhs
      default:
        return false
      }
    }
  }

  public struct Notification: Equatable {
    public var date: Date
    public var request: UNNotificationRequest

    public init(
      date: Date,
      request: UNNotificationRequest
    ) {
      self.date = date
      self.request = request
    }

    public struct Response: Equatable {
      public var notification: Notification

      public init(notification: Notification) {
        self.notification = notification
      }
    }

    // TODO: should this be nested in UserNotificationClient instead of Notification?
    public struct Settings: Equatable {
      public var authorizationStatus: UNAuthorizationStatus

      public init(authorizationStatus: UNAuthorizationStatus) {
        self.authorizationStatus = authorizationStatus
      }
    }
  }
}
