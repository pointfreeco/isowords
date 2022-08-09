import ServerConfig

extension ServerConfigClient {
  public static let noop = Self(
    config: { .init() },
    refresh: { try await Task.never() }
  )
}

#if DEBUG
  import XCTestDynamicOverlay

  extension ServerConfigClient {
    public static let unimplemented = Self(
      config: XCTUnimplemented("\(Self.self).config", placeholder: ServerConfig()),
      refresh: XCTUnimplemented("\(Self.self).refresh")
    )
  }
#endif
