import Combine
import ComposableUserNotifications
import RemoteNotificationsClient

public func registerForRemoteNotifications(
  remoteNotifications: RemoteNotificationsClient,
  userNotifications: UserNotificationClient
) async {
  switch await userNotifications.getNotificationSettings().authorizationStatus {
  case .authorized, .provisional:
    await remoteNotifications.register()
  case .notDetermined, .denied, .ephemeral:
    return
  @unknown default:
    return
  }
}
