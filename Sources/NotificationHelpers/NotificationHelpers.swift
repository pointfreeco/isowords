import Combine
import ComposableUserNotifications
import RemoteNotificationsClient

public func registerForRemoteNotifications(
  remoteNotifications: RemoteNotificationsClient,
  userNotifications: UserNotificationClient
) async {
  switch await userNotifications.getNotificationSettings().authorizationStatus {
  case .notDetermined, .denied, .ephemeral:
    return
  case .authorized, .provisional:
    await remoteNotifications.register()
  @unknown default:
    return
  }
}
