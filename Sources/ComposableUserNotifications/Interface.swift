import Combine
import ComposableArchitecture
import UserNotifications

public struct UserNotificationClient {
  public var add: @Sendable (UNNotificationRequest) async throws -> Void
  public var delegate: @Sendable () -> AsyncStream<DelegateEvent>
  public var getNotificationSettings: @Sendable () async -> Notification.Settings
  public var removeDeliveredNotificationsWithIdentifiers: @Sendable ([String]) async -> Void
  public var removePendingNotificationRequestsWithIdentifiers: @Sendable ([String]) async -> Void
  public var requestAuthorization: @Sendable (UNAuthorizationOptions) async throws -> Bool

  @CasePathable
  public enum DelegateEvent {
    case didReceiveResponse(Notification.Response, completionHandler: @Sendable () -> Void)
    case openSettingsForNotification(Notification?)
    case willPresentNotification(
      Notification, completionHandler: @Sendable (UNNotificationPresentationOptions) -> Void
    )
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
