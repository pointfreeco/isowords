#if canImport(UIKit)
  import UIKit

  @available(iOSApplicationExtension, unavailable)
  extension RemoteNotificationsClient {
    public static let live = Self(
      isRegistered: { UIApplication.shared.isRegisteredForRemoteNotifications },
      isRegisteredAsync: { await UIApplication.shared.isRegisteredForRemoteNotifications },
      register: {
        .fireAndForget {
          UIApplication.shared.registerForRemoteNotifications()
        }
      },
      registerAsync: { await UIApplication.shared.registerForRemoteNotifications() },
      unregister: {
        .fireAndForget {
          UIApplication.shared.unregisterForRemoteNotifications()
        }
      },
      unregisterAsync: { await UIApplication.shared.unregisterForRemoteNotifications() }
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
