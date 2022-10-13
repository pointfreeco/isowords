import Dependencies
import XCTestDynamicOverlay

extension DependencyValues {
  public var remoteNotifications: RemoteNotificationsClient {
    get { self[RemoteNotificationsClient.self] }
    set { self[RemoteNotificationsClient.self] = newValue }
  }
}

extension RemoteNotificationsClient: TestDependencyKey {
  public static let previewValue = Self.noop

  public static let testValue = Self(
    isRegistered: XCTUnimplemented("\(Self.self).isRegistered", placeholder: false),
    register: XCTUnimplemented("\(Self.self).register"),
    unregister: XCTUnimplemented("\(Self.self).unregister")
  )
}

extension RemoteNotificationsClient {
  public static let noop = Self(
    isRegistered: { true },
    register: {},
    unregister: {}
  )
}
