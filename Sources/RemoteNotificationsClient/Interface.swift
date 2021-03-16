import ComposableArchitecture

public struct RemoteNotificationsClient {
  public var isRegistered: () -> Bool
  public var register: () -> Effect<Never, Never>
  public var unregister: () -> Effect<Never, Never>
}

extension RemoteNotificationsClient {
  public static let noop = Self(
    isRegistered: { true },
    register: { .none },
    unregister: { .none }
  )
}

#if DEBUG
  import XCTestDebugSupport

  extension RemoteNotificationsClient {
    public static let failing = Self(
      isRegistered: {
        XCTFail("\(Self.self).isRegistered is unimplemented")
        return false
      },
      register: { .failing("\(Self.self).register is unimplemented") },
      unregister: { .failing("\(Self.self).unregister is unimplemented") }
    )
  }
#endif
