import Dependencies
import Foundation
import XCTestDynamicOverlay

public struct DeviceIdentifier {
  public var id: () -> UUID
}

extension DependencyValues {
  public var deviceId: DeviceIdentifier {
    get { self[DeviceIdentifier.self] }
    set { self[DeviceIdentifier.self] = newValue }
  }
}

extension DeviceIdentifier: TestDependencyKey {
  public static let previewValue = Self.noop

  public static let testValue = Self(
    id: unimplemented("\(Self.self).id", placeholder: UUID())
  )
}

extension DeviceIdentifier: DependencyKey {
  public static let liveValue = Self(
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

extension DeviceIdentifier {
  public static let noop = Self(
    id: { UUID(uuidString: "deadbeef-dead-beef-dead-beefdeadbeef")! }
  )
}

private let deviceIdKey = "co.pointfree.device-id"
