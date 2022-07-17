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
    public static let failing = Self(
      config: {
        XCTFail("\(Self.self).config is unimplemented")
        return .init()
      },
      refresh: XCTUnimplemented("\(Self.self).refresh")
    )
  }
#endif
