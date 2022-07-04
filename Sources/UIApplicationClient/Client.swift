import ComposableArchitecture
import UIKit

public struct UIApplicationClient {
  public var alternateIconName: () -> String?
  public var alternateIconNameAsync: @Sendable () async -> String?
  public var open: (URL, [UIApplication.OpenExternalURLOptionsKey: Any]) -> Effect<Bool, Never>
  public var openAsync: @Sendable (URL, [UIApplication.OpenExternalURLOptionsKey: Any]) async -> Bool
  public var openSettingsURLString: () -> String
  public var openSettingsURLStringAsync: @Sendable () async -> String
  public var setAlternateIconName: (String?) -> Effect<Never, Error>
  public var setAlternateIconNameAsync: @Sendable (String?) async throws -> Void
  public var supportsAlternateIcons: () -> Bool
  public var supportsAlternateIconsAsync: @Sendable () async -> Bool
}
