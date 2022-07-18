import ComposableArchitecture
import XCTestDynamicOverlay

extension UIApplicationClient {
  #if DEBUG
    public static let failing = Self(
      alternateIconName: {
        XCTFail("\(Self.self).alternateIconName is unimplemented")
        return nil
      },
      alternateIconNameAsync: XCTUnimplemented("\(Self.self).alternateIconNameAsync"),
      open: XCTUnimplemented("\(Self.self).open", placeholder: false),
      openSettingsURLString: XCTUnimplemented("\(Self.self).openSettingsURLString"),
      setAlternateIconName: XCTUnimplemented("\(Self.self).setAlternateIconName"),
      supportsAlternateIcons: {
        XCTFail("\(Self.self).supportsAlternateIcons is unimplemented")
        return false
      },
      supportsAlternateIconsAsync: XCTUnimplemented(
        "\(Self.self).setAlternateIconNameAsync", placeholder: false
      )
    )
  #endif

  public static let noop = Self(
    alternateIconName: { nil },
    alternateIconNameAsync: { nil },
    open: { _, _ in false},
    openSettingsURLString: { "settings://isowords/settings" },
    setAlternateIconName: { _ in },
    supportsAlternateIcons: { true },
    supportsAlternateIconsAsync: { true }
  )
}
