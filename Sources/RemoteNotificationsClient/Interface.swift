public struct RemoteNotificationsClient {
  public var isRegistered: () -> Bool
  public var register: () async -> Void
  public var unregister: () async -> Void
}

extension RemoteNotificationsClient {
  public static let noop = Self(
    isRegistered: { true },
    register: { },
    unregister: { }
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
      register: { XCTFail("\(Self.self).register is unimplemented") },
      unregister: { XCTFail("\(Self.self).unregister is unimplemented") }
    )
  }
#endif
