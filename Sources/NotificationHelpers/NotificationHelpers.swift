import Combine
import ComposableArchitecture
import ComposableUserNotifications
import RemoteNotificationsClient

extension Effect where Output == Never, Failure == Never {
  public static func registerForRemoteNotifications<S: Scheduler>(
    remoteNotifications: RemoteNotificationsClient,
    scheduler: S,
    userNotifications: UserNotificationClient
  ) -> Self {
    userNotifications.getNotificationSettings
      .receive(on: scheduler)
      .flatMap { settings in
        settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
          ? remoteNotifications.register()
          : .none
      }
      .receive(on: scheduler)
      .eraseToEffect()
  }
}

public func registerForRemoteNotificationsAsync(
  remoteNotifications: RemoteNotificationsClient,
  userNotifications: UserNotificationClient
) async {
  let settings = await userNotifications.getNotificationSettingsAsync()
  guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
  else { return }
  await remoteNotifications.registerAsync()
}
