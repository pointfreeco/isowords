extension UserNotificationClient {
  public static let noop = Self(
    add: { _ in .none },
    delegate: .none,
    getNotificationSettings: .none,
    removeDeliveredNotificationsWithIdentifiers: { _ in .none },
    removePendingNotificationRequestsWithIdentifiers: { _ in .none },
    requestAuthorization: { _ in .none }
  )
}

#if DEBUG
  import XCTestDynamicOverlay

  extension UserNotificationClient {
    public static let failing = Self(
      add: { _ in .failing("\(Self.self).add is not implemented") },
      delegate: .failing("\(Self.self).delegate is not implemented"),
      getNotificationSettings: .failing("\(Self.self).getNotificationSettings is not implemented"),
      removeDeliveredNotificationsWithIdentifiers: { _ in
        .failing("\(Self.self).removeDeliveredNotificationsWithIdentifiers is not implemented")
      },
      removePendingNotificationRequestsWithIdentifiers: { _ in
        .failing("\(Self.self).removePendingNotificationRequestsWithIdentifiers is not implemented")
      },
      requestAuthorization: { _ in .failing("\(Self.self).requestAuthorization is not implemented")
      }
    )
  }
#endif
