import ComposableArchitecture
import XCTestDynamicOverlay

extension UIApplicationClient {
  #if DEBUG
    public static let unimplemented = Self(
      alternateIconName: XCTUnimplemented("\(Self.self).alternateIconName"),
      alternateIconNameAsync: XCTUnimplemented("\(Self.self).alternateIconNameAsync"),
      open: XCTUnimplemented("\(Self.self).open", placeholder: false),
      openSettingsURLString: XCTUnimplemented("\(Self.self).openSettingsURLString"),
      setAlternateIconName: XCTUnimplemented("\(Self.self).setAlternateIconName"),
      supportsAlternateIcons: XCTUnimplemented(
        "\(Self.self).supportsAlternateIcons", placeholder: false
      ),
      supportsAlternateIconsAsync: XCTUnimplemented(
        "\(Self.self).setAlternateIconNameAsync", placeholder: false
      )
    )
  #endif

  public static let noop = Self(
    alternateIconName: { nil },
    alternateIconNameAsync: { nil },
    open: { _, _ in false },
    openSettingsURLString: { "settings://isowords/settings" },
    setAlternateIconName: { _ in },
    supportsAlternateIcons: { true },
    supportsAlternateIconsAsync: { true }
  )
}
