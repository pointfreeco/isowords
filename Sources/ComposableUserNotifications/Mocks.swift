extension UserNotificationClient {
  public static let noop = Self(
    add: { _ in .none },
    addAsync: { _ in },
    delegate: .none,
    delegateAsync: { AsyncStream { _ in } },
    getNotificationSettings: { Notification.Settings(authorizationStatus: .notDetermined) },
    removeDeliveredNotificationsWithIdentifiers: { _ in .none },
    removeDeliveredNotificationsWithIdentifiersAsync: { _ in },
    removePendingNotificationRequestsWithIdentifiers: { _ in .none },
    removePendingNotificationRequestsWithIdentifiersAsync: { _ in },
    requestAuthorization: { _ in .none },
    requestAuthorizationAsync: { _ in false }
  )
}

#if DEBUG
  import XCTestDynamicOverlay

  extension UserNotificationClient {
    public static let failing = Self(
      add: { _ in .failing("\(Self.self).add is not implemented") },
      addAsync: XCTUnimplemented("\(Self.self).addAsync"),
      delegate: .failing("\(Self.self).delegate is not implemented"),
      delegateAsync: XCTUnimplemented("\(Self.self).delegateAsync", placeholder: .finished),
      getNotificationSettings: XCTUnimplemented(
        "\(Self.self).getNotificationSettings",
        placeholder: Notification.Settings(authorizationStatus: .notDetermined)
      ),
      removeDeliveredNotificationsWithIdentifiers: { _ in
        .failing("\(Self.self).removeDeliveredNotificationsWithIdentifiers is not implemented")
      },
      removeDeliveredNotificationsWithIdentifiersAsync: XCTUnimplemented(
        "\(Self.self).removeDeliveredNotificationsWithIdentifiersAsync"),
      removePendingNotificationRequestsWithIdentifiers: { _ in
        .failing("\(Self.self).removePendingNotificationRequestsWithIdentifiers is not implemented")
      },
      removePendingNotificationRequestsWithIdentifiersAsync: XCTUnimplemented(
        "\(Self.self).removePendingNotificationRequestsWithIdentifiersAsync"),
      requestAuthorization: { _ in
        .failing("\(Self.self).requestAuthorization is not implemented")
      },
      requestAuthorizationAsync: XCTUnimplemented("\(Self.self).requestAuthorizationAsync")
    )
  }
#endif
