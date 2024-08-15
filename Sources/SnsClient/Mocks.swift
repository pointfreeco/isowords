import ServerTestHelpers
import IssueReporting

#if DEBUG
  extension SnsClient {
    public static let testValue = Self(
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
