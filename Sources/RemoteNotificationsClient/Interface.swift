import ComposableArchitecture

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
    public static let failing = Self(
      isRegistered: XCTUnimplemented("\(Self.self).isRegistered", placeholder: false),
      register: XCTUnimplemented("\(Self.self).register"),
      unregister: XCTUnimplemented("\(Self.self).unregister")
    )
  }
#endif
