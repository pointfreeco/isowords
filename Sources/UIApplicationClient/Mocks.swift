import ComposableArchitecture
import XCTestDynamicOverlay

extension UIApplicationClient {
  #if DEBUG
    public static let failing = Self(
      alternateIconName: {
        XCTFail("\(Self.self).alternateIconName is unimplemented")
        return nil
      },
      open: { _, _ in .failing("\(Self.self).open is unimplemented") },
      openSettingsURLString: {
        XCTFail("\(Self.self).openSettingsURLString is unimplemented")
        return ""
      },
      setAlternateIconName: { _ in .failing("\(Self.self).setAlternateIconName is unimplemented") },
      supportsAlternateIcons: {
        XCTFail("\(Self.self).supportsAlternateIcons is unimplemented")
        return false
      }
    )
  #endif

  public static let noop = Self(
    alternateIconName: { nil },
    open: { _, _ in .none },
    openSettingsURLString: { "settings://isowords/settings" },
    setAlternateIconName: { _ in .none },
    supportsAlternateIcons: { true }
  )
}
