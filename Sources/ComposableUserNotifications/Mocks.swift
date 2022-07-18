extension UserNotificationClient {
  public static let noop = Self(
    add: { _ in },
    delegate: { AsyncStream { _ in } },
    getNotificationSettings: { Notification.Settings(authorizationStatus: .notDetermined) },
    removeDeliveredNotificationsWithIdentifiers: { _ in },
    removePendingNotificationRequestsWithIdentifiers: { _ in },
    requestAuthorization: { _ in false }
  )
}

#if DEBUG
  import XCTestDynamicOverlay

  extension UserNotificationClient {
    public static let failing = Self(
      add: XCTUnimplemented("\(Self.self).add"),
      delegate: XCTUnimplemented("\(Self.self).delegate", placeholder: .finished),
      getNotificationSettings: XCTUnimplemented(
        "\(Self.self).getNotificationSettings",
        placeholder: Notification.Settings(authorizationStatus: .notDetermined)
      ),
      removeDeliveredNotificationsWithIdentifiers: XCTUnimplemented(
        "\(Self.self).removeDeliveredNotificationsWithIdentifiers"),
      removePendingNotificationRequestsWithIdentifiers: XCTUnimplemented(
        "\(Self.self).removePendingNotificationRequestsWithIdentifiers"),
      requestAuthorization: XCTUnimplemented("\(Self.self).requestAuthorization")
    )
  }
#endif
