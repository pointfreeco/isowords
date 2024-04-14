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
