import ComposableArchitecture
import XCTestDynamicOverlay

extension UIApplicationClient {
  #if DEBUG
    public static let failing = Self(
      alternateIconName: {
        XCTFail("\(Self.self).alternateIconName is unimplemented")
        return nil
      },
      alternateIconNameAsync: XCTUnimplemented("\(Self.self).alternateIconName"),
      open: { _, _ in .failing("\(Self.self).open is unimplemented") },
      openAsync: XCTUnimplemented("\(Self.self).openAsync", placeholder: false),
      openSettingsURLString: {
        XCTFail("\(Self.self).openSettingsURLString is unimplemented")
        return ""
      },
      openSettingsURLStringAsync: XCTUnimplemented("\(Self.self).openSettingsURLStringAsync"),
      setAlternateIconName: { _ in .failing("\(Self.self).setAlternateIconName is unimplemented") },
      setAlternateIconNameAsync: XCTUnimplemented("\(Self.self).setAlternateIconNameAsync"),
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
    open: { _, _ in .none },
    openAsync: { _, _ in false},
    openSettingsURLString: { "settings://isowords/settings" },
    openSettingsURLStringAsync: { "settings://isowords/settings" },
    setAlternateIconName: { _ in .none },
    setAlternateIconNameAsync: { _ in },
    supportsAlternateIcons: { true },
    supportsAlternateIconsAsync: { true }
  )
}
