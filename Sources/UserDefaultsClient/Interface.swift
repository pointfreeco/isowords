import ComposableArchitecture
import Foundation

extension DependencyValues {
  public var userDefaults: UserDefaultsClient {
    get { self[UserDefaultsClientKey.self] }
    set { self[UserDefaultsClientKey.self] = newValue }
  }

  private enum UserDefaultsClientKey: LiveDependencyKey {
    static let liveValue = UserDefaultsClient.live(userDefaults: .standard)
    static let testValue = UserDefaultsClient.failing
  }
}

public struct UserDefaultsClient {
  public var boolForKey: (String) -> Bool
  public var dataForKey: (String) -> Data?
  public var doubleForKey: (String) -> Double
  public var integerForKey: (String) -> Int
  public var remove: (String) -> Effect<Never, Never>
  public var setBool: (Bool, String) -> Effect<Never, Never>
  public var setData: (Data?, String) -> Effect<Never, Never>
  public var setDouble: (Double, String) -> Effect<Never, Never>
  public var setInteger: (Int, String) -> Effect<Never, Never>

  public var hasShownFirstLaunchOnboarding: Bool {
    self.boolForKey(hasShownFirstLaunchOnboardingKey)
  }

  public func setHasShownFirstLaunchOnboarding(_ bool: Bool) -> Effect<Never, Never> {
    self.setBool(bool, hasShownFirstLaunchOnboardingKey)
  }

  public var installationTime: Double {
    self.doubleForKey(installationTimeKey)
  }

  public func setInstallationTime(_ double: Double) -> Effect<Never, Never> {
    self.setDouble(double, installationTimeKey)
  }

  public func incrementMultiplayerOpensCount() -> Effect<Int, Never> {
    let incremented = self.integerForKey(multiplayerOpensCount) + 1
    return .concatenate(
      self.setInteger(incremented, multiplayerOpensCount).fireAndForget(),
      .init(value: incremented)
    )
  }
}

let hasShownFirstLaunchOnboardingKey = "hasShownFirstLaunchOnboardingKey"
let installationTimeKey = "installationTimeKey"
let multiplayerOpensCount = "multiplayerOpensCount"
