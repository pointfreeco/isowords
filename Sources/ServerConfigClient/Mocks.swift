import ServerConfig

extension ServerConfigClient {
  public static let noop = Self(
    config: { .init() },
    refresh: { .init() }
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
      refresh: {
        XCTFail("\(Self.self).refresh is unimplemented")
        struct Unimplemented: Error {}
        throw Unimplemented()
      }
    )
  }
#endif
