import Combine
import ComposableArchitecture
import ComposableUserNotifications
import RemoteNotificationsClient

extension Effect where Output == Never, Failure == Never {
  public static func registerForRemoteNotifications(
    mainQueue: AnySchedulerOf<DispatchQueue>,
    remoteNotifications: RemoteNotificationsClient,
    userNotifications: UserNotificationClient
  ) -> Self {
    userNotifications.getNotificationSettings
      .receive(on: mainQueue)
      .flatMap { settings in
        settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
          ? remoteNotifications.register()
          : .none
      }
      .eraseToEffect()
  }
}
