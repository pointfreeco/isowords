//import Dependencies
//import DependenciesMacros
//import Foundation
//
//extension DependencyValues {
//  public var userDefaults: UserDefaultsClient {
//    get { self[UserDefaultsClient.self] }
//    set { self[UserDefaultsClient.self] = newValue }
//  }
//}
//
//@DependencyClient
//public struct UserDefaultsClient {
//  public var boolForKey: @Sendable (String) -> Bool = { _ in false }
//  public var dataForKey: @Sendable (String) -> Data?
//  public var doubleForKey: @Sendable (String) -> Double = { _ in 0 }
//  public var integerForKey: @Sendable (String) -> Int = { _ in 0 }
//  public var remove: @Sendable (String) async -> Void
//  public var setBool: @Sendable (Bool, String) async -> Void
//  public var setData: @Sendable (Data?, String) async -> Void
//  public var setDouble: @Sendable (Double, String) async -> Void
//  public var setInteger: @Sendable (Int, String) async -> Void
//
//  public var hasShownFirstLaunchOnboarding: Bool {
//    self.boolForKey(hasShownFirstLaunchOnboardingKey)
//  }
//
//  public func setHasShownFirstLaunchOnboarding(_ bool: Bool) async {
//    await self.setBool(bool, hasShownFirstLaunchOnboardingKey)
//  }
//
//  public var installationTime: Double {
//    self.doubleForKey(installationTimeKey)
//  }
//
//  public func setInstallationTime(_ double: Double) async {
//    await self.setDouble(double, installationTimeKey)
//  }
//
//  public func incrementMultiplayerOpensCount() async -> Int {
//    let incremented = self.integerForKey(multiplayerOpensCount) + 1
//    await self.setInteger(incremented, multiplayerOpensCount)
//    return incremented
//  }
//}
//
//let hasShownFirstLaunchOnboardingKey = "hasShownFirstLaunchOnboardingKey"
//let installationTimeKey = "installationTimeKey"
//let multiplayerOpensCount = "multiplayerOpensCount"

import ComposableArchitecture

extension PersistenceKey where Self == AppStorageKey<Double> {
  public static var installationTime: Self {
    appStorage("installationTimeKey")
  }
}
extension PersistenceKey where Self == AppStorageKey<Bool> {
  public static var hasShownFirstLaunchOnboarding: Self {
    AppStorageKey("hasShownFirstLaunchOnboardingKey")
  }
}
extension PersistenceKey where Self == AppStorageKey<Int> {
  public static var multiplayerOpensCount: Self {
    AppStorageKey("multiplayerOpensCount")
  }
}
extension PersistenceKey where Self == AppStorageKey<Double> {
  public static var lastReviewRequest: Self {
    AppStorageKey("last-review-request-timeinterval")
  }
}
