import UIKit

@available(iOSApplicationExtension, unavailable)
extension RemoteNotificationsClient {
  public static let live = Self(
    isRegistered: { await UIApplication.shared.isRegisteredForRemoteNotifications },
    register: { await UIApplication.shared.registerForRemoteNotifications() },
    unregister: { await UIApplication.shared.unregisterForRemoteNotifications() }
  )
}
