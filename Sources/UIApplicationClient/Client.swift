import ComposableArchitecture
import UIKit

public struct UIApplicationClient {
  @available(*, deprecated) public var alternateIconName: () -> String?
  public var alternateIconNameAsync: @Sendable () async -> String?
  @available(*, deprecated) public var open: (URL, [UIApplication.OpenExternalURLOptionsKey: Any]) -> Effect<Bool, Never>
  public var openAsync: @Sendable (URL, [UIApplication.OpenExternalURLOptionsKey: Any]) async -> Bool
  @available(*, deprecated) public var openSettingsURLString: () -> String
  public var openSettingsURLStringAsync: @Sendable () async -> String
  @available(*, deprecated) public var setAlternateIconName: (String?) -> Effect<Never, Error>
  public var setAlternateIconNameAsync: @Sendable (String?) async throws -> Void
  @available(*, deprecated) public var supportsAlternateIcons: () -> Bool
  public var supportsAlternateIconsAsync: @Sendable () async -> Bool
}
