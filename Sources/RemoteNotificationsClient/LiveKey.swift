import Dependencies
import UIKit

@available(iOSApplicationExtension, unavailable)
extension RemoteNotificationsClient: DependencyKey {
  public static let liveValue = Self(
    isRegistered: { await UIApplication.shared.isRegisteredForRemoteNotifications },
    register: { await UIApplication.shared.registerForRemoteNotifications() },
    unregister: { await UIApplication.shared.unregisterForRemoteNotifications() }
  )
}
