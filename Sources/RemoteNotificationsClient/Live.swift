#if canImport(UIKit)
  import UIKit

  @available(iOSApplicationExtension, unavailable)
  extension RemoteNotificationsClient {
    public static let live = Self(
      isRegistered: { UIApplication.shared.isRegisteredForRemoteNotifications },
      register: {
        // TODO: why does this need await?
        await UIApplication.shared.registerForRemoteNotifications()
      },
      unregister: {
        await UIApplication.shared.unregisterForRemoteNotifications()
      }
    )
  }
#elseif canImport(AppKit)
  import AppKit

  extension RemoteNotificationsClient {
    public static let live = Self(
      isRegistered: { NSApplication.shared.isRegisteredForRemoteNotifications },
      register: {
        .fireAndForget {
          NSApplication.shared.registerForRemoteNotifications()
        }
      },
      unregister: {
        .fireAndForget {
          NSApplication.shared.unregisterForRemoteNotifications()
        }
      }
    )
  }
#endif
