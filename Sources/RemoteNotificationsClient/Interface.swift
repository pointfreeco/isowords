import ComposableArchitecture

extension DependencyValues {
  public var remoteNotifications: RemoteNotificationsClient {
    get { self[RemoteNotificationsClientKey.self] }
    set { self[RemoteNotificationsClientKey.self] = newValue }
  }

  private enum RemoteNotificationsClientKey: LiveDependencyKey {
    static let liveValue = RemoteNotificationsClient.live
    static let testValue = RemoteNotificationsClient.unimplemented
  }
}

public struct RemoteNotificationsClient {
  public var isRegistered: @Sendable () async -> Bool
  public var register: @Sendable () async -> Void
  public var unregister: @Sendable () async -> Void
}

extension RemoteNotificationsClient {
  public static let noop = Self(
    isRegistered: { true },
    register: {},
    unregister: {}
  )
}

#if DEBUG
  import XCTestDynamicOverlay

  extension RemoteNotificationsClient {
    public static let unimplemented = Self(
      isRegistered: XCTUnimplemented("\(Self.self).isRegistered", placeholder: false),
      register: XCTUnimplemented("\(Self.self).register"),
      unregister: XCTUnimplemented("\(Self.self).unregister")
    )
  }
#endif
