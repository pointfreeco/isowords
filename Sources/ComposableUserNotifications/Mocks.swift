extension UserNotificationClient {
  public static let noop = Self(
    add: { _ in },
    delegate: .none,
    getNotificationSettings: { .init(authorizationStatus: .authorized) },
    removeDeliveredNotificationsWithIdentifiers: { _ in },
    removePendingNotificationRequestsWithIdentifiers: { _ in },
    requestAuthorization: { _ in true }
  )
}

#if DEBUG
  import XCTestDynamicOverlay

  extension UserNotificationClient {
    public static let failing = Self(
      add: { _ in
        XCTFail("\(Self.self).add is not implemented")
      },
      delegate: .failing("\(Self.self).delegate is not implemented"),
      getNotificationSettings: {
        XCTFail("\(Self.self).getNotificationSettings is not implemented")
        return .init(authorizationStatus: .authorized)
      },
      removeDeliveredNotificationsWithIdentifiers: { _ in
        XCTFail("\(Self.self).removeDeliveredNotificationsWithIdentifiers is not implemented")
      },
      removePendingNotificationRequestsWithIdentifiers: { _ in
        XCTFail("\(Self.self).removePendingNotificationRequestsWithIdentifiers is not implemented")
      },
      requestAuthorization: { _ in
        XCTFail("\(Self.self).requestAuthorization is not implemented")
        return false
      }
    )
  }
#endif
