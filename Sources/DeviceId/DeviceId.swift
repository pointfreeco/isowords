import Foundation

public struct DeviceIdentifier {
  public var id: () -> UUID
}

extension DeviceIdentifier {
  public static let live = Self(
    id: {
      if let uuidString = NSUbiquitousKeyValueStore.default.string(forKey: deviceIdKey),
        let uuid = UUID.init(uuidString: uuidString)
      {

        return uuid
      }

      let uuid = UUID()
      NSUbiquitousKeyValueStore.default.set(uuid.uuidString, forKey: deviceIdKey)
      return uuid
    }
  )
}

#if DEBUG
  import XCTestDynamicOverlay

  extension DeviceIdentifier {
    public static let failing = Self(
      id: {
        XCTFail("\(Self.self).id is unimplemented")
        return UUID()
      }
    )

    public static let noop = Self(
      id: { UUID(uuidString: "deadbeef-dead-beef-dead-beefdeadbeef")! }
    )
  }
#endif

private let deviceIdKey = "co.pointfree.device-id"
