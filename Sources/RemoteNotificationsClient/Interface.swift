import ComposableArchitecture

public struct RemoteNotificationsClient {
  @available(*, deprecated) public var isRegistered: () -> Bool
  public var isRegisteredAsync: @Sendable () async -> Bool
  @available(*, deprecated) public var register: () -> Effect<Never, Never>
  public var registerAsync: @Sendable () async -> Void
  @available(*, deprecated) public var unregister: () -> Effect<Never, Never>
  public var unregisterAsync: @Sendable () async -> Void
}

extension RemoteNotificationsClient {
  public static let noop = Self(
    isRegistered: { true },
    isRegisteredAsync: { true },
    register: { .none },
    registerAsync: {},
    unregister: { .none },
    unregisterAsync: {}
  )
}

#if DEBUG
  import XCTestDynamicOverlay

  extension RemoteNotificationsClient {
    public static let failing = Self(
      isRegistered: {
        XCTFail("\(Self.self).isRegistered is unimplemented")
        return false
      },
      isRegisteredAsync: XCTUnimplemented("\(Self.self).isRegisteredAsync", placeholder: false),
      register: { .failing("\(Self.self).register is unimplemented") },
      registerAsync: XCTUnimplemented("\(Self.self).registerAsync"),
      unregister: { .failing("\(Self.self).unregister is unimplemented") },
      unregisterAsync: XCTUnimplemented("\(Self.self).unregisterAsync")
    )
  }
#endif
