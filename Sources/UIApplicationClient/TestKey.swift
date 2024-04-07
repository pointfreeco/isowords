import Dependencies

extension DependencyValues {
  public var applicationClient: UIApplicationClient {
    get { self[UIApplicationClient.self] }
    set { self[UIApplicationClient.self] = newValue }
  }
}

extension UIApplicationClient: TestDependencyKey {
  public static let previewValue = Self.noop
  public static let testValue = Self()
}

extension UIApplicationClient {
  public static let noop = Self(
    alternateIconName: { nil },
    alternateIconNameAsync: { nil },
    open: { _, _ in false },
    openSettingsURLString: { "settings://isowords/settings" },
    setAlternateIconName: { _ in },
    setUserInterfaceStyle: { _ in },
    supportsAlternateIconsAsync: { true }
  )
}
