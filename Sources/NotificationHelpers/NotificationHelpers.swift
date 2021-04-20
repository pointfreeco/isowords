import Combine
import ComposableArchitecture
import ComposableUserNotifications
import RemoteNotificationsClient

extension Effect where Output == Never, Failure == Never {
  public static func registerForRemoteNotifications(
    mainRunLoop: AnySchedulerOf<RunLoop>,
    remoteNotifications: RemoteNotificationsClient,
    userNotifications: UserNotificationClient
  ) -> Self {
    userNotifications.getNotificationSettings
      .receive(on: mainRunLoop)
      .flatMap { settings in
        settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
          ? remoteNotifications.register()
          : .none
      }
      .eraseToEffect()
  }
}
