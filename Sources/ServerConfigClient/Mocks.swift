import ServerConfig

extension ServerConfigClient {
  public static let noop = Self(
    config: { .init() },
    refresh: { .none },
    refreshAsync: { try await Task.never() }
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
      refresh: { .failing("\(Self.self).refresh is unimplemented") },
      refreshAsync: XCTUnimplemented("\(Self.self).refreshAsync")
    )
  }
#endif
