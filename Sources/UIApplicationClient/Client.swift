import ComposableArchitecture
import UIKit

extension DependencyValues {
  public var applicationClient: UIApplicationClient {
    get { self[UIApplicationClientKey.self] }
    set { self[UIApplicationClientKey.self] = newValue }
  }

  private enum UIApplicationClientKey: LiveDependencyKey {
    static let liveValue = UIApplicationClient.live
    static let testValue = UIApplicationClient.failing
  }
}

public struct UIApplicationClient {
  public var alternateIconName: () -> String?
  public var open: (URL, [UIApplication.OpenExternalURLOptionsKey: Any]) -> Effect<Bool, Never>
  public var openSettingsURLString: () -> String
  public var setAlternateIconName: (String?) -> Effect<Never, Error>
  public var supportsAlternateIcons: () -> Bool
}
