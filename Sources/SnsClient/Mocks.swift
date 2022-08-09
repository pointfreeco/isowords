import ServerTestHelpers
import XCTestDynamicOverlay

#if DEBUG
  extension SnsClient {
    public static let unimplemented = Self(
      createPlatformEndpoint: { _ in
        .unimplemented("\(Self.self).createPlatformEndpoint is not implemented.")
      },
      deleteEndpoint: { _ in
        .unimplemented("(Self.self).deleteEndpoint is not implemented.")
      },
      publish: { _, _ in
        .unimplemented("(Self.self).publish is not implemented.")
      }
    )
  }
#endif
