import Dependencies
import XCTestDynamicOverlay

extension DependencyValues {
  public var applicationClient: UIApplicationClient {
    get { self[UIApplicationClient.self] }
    set { self[UIApplicationClient.self] = newValue }
  }
}

extension UIApplicationClient: TestDependencyKey {
  public static let previewValue = Self.noop

  public static let testValue = Self(
    alternateIconName: unimplemented("\(Self.self).alternateIconName"),
    alternateIconNameAsync: unimplemented("\(Self.self).alternateIconNameAsync"),
    open: unimplemented("\(Self.self).open", placeholder: false),
    openSettingsURLString: unimplemented("\(Self.self).openSettingsURLString"),
    setAlternateIconName: unimplemented("\(Self.self).setAlternateIconName"),
    setUserInterfaceStyle: unimplemented("\(Self.self).setUserInterfaceStyle"),
    supportsAlternateIcons: unimplemented(
      "\(Self.self).supportsAlternateIcons", placeholder: false
    ),
    supportsAlternateIconsAsync: unimplemented(
      "\(Self.self).setAlternateIconNameAsync", placeholder: false
    )
  )
}

extension UIApplicationClient {
  public static let noop = Self(
    alternateIconName: { nil },
    alternateIconNameAsync: { nil },
    open: { _, _ in false },
    openSettingsURLString: { "settings://isowords/settings" },
    setAlternateIconName: { _ in },
    setUserInterfaceStyle: { _ in },
    supportsAlternateIcons: { true },
    supportsAlternateIconsAsync: { true }
  )
}
