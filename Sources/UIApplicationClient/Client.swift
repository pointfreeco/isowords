import DependenciesMacros
import UIKit

@DependencyClient
public struct UIApplicationClient {
  // TODO: Should these endpoints be merged and `@MainActor`? Should `Reducer` be `@MainActor`?
  public var alternateIconName: () -> String?
  public var alternateIconNameAsync: @Sendable () async -> String?
  public var open: @Sendable (URL, [UIApplication.OpenExternalURLOptionsKey: Any]) async -> Bool = {
    _, _ in false
  }
  public var openSettingsURLString: @Sendable () async -> String = { "" }
  public var setAlternateIconName: @Sendable (String?) async throws -> Void
  // TODO: Should these endpoints be merged and `@MainActor`? Should `Reducer` be `@MainActor`?
  public var setUserInterfaceStyle: @Sendable (UIUserInterfaceStyle) async -> Void
  public var supportsAlternateIconsAsync: @Sendable () async -> Bool = { false }
}
