import ServerTestHelpers
import XCTestDynamicOverlay

#if DEBUG
  extension SnsClient {
    public static let failing = Self(
      createPlatformEndpoint: { _ in
        .failing("\(Self.self).createPlatformEndpoint is not implemented.")
      },
      deleteEndpoint: { _ in
        .failing("(Self.self).deleteEndpoint is not implemented.")
      },
      publish: { _, _ in
        .failing("(Self.self).publish is not implemented.")
      }
    )
  }
#endif
