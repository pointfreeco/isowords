import ServerConfig

extension ServerConfigClient {
  public static let noop = Self(
    config: { .init() },
    refresh: { .none }
  )
}

#if DEBUG
  import XCTestDebugSupport

  extension ServerConfigClient {
    public static let failing = Self(
      config: {
        XCTFail("\(Self.self).config is unimplemented")
        return .init()
      },
      refresh: { .failing("\(Self.self).refresh is unimplemented") }
    )
  }
#endif
