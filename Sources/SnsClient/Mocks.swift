#if DEBUG
  extension SnsClient {
    public static let unimplemented = Self(
      createPlatformEndpoint: { _ in
        fatalError("SnsClient.createPlatformEndpoint is not implemented.")
      },
      deleteEndpoint: { _ in fatalError("SnsClient.deleteEndpoint is not implemented.") },
      publish: { _, _ in fatalError("SnsClient.publish is not implemented.") }
    )
  }
#endif
