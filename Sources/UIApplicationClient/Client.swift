import ComposableArchitecture
import UIKit

public struct UIApplicationClient {
  @available(*, deprecated) public var alternateIconName: () -> String?
  public var alternateIconNameAsync: @Sendable () async -> String?
  public var open: @Sendable (URL, [UIApplication.OpenExternalURLOptionsKey: Any]) async -> Bool
  public var openSettingsURLString: @Sendable () async -> String
  public var setAlternateIconName: @Sendable (String?) async throws -> Void
  @available(*, deprecated) public var supportsAlternateIcons: () -> Bool
  public var supportsAlternateIconsAsync: @Sendable () async -> Bool
}
