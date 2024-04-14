import ComposableArchitecture

extension PersistenceReaderKey where Self == AppStorageKey<Double> {
  public static var installationTime: Self {
    appStorage("installationTimeKey")
  }
}
extension PersistenceReaderKey where Self == AppStorageKey<Bool> {
  public static var hasShownFirstLaunchOnboarding: Self {
    AppStorageKey("hasShownFirstLaunchOnboardingKey")
  }
}
extension PersistenceReaderKey where Self == AppStorageKey<Int> {
  public static var multiplayerOpensCount: Self {
    AppStorageKey("multiplayerOpensCount")
  }
}
extension PersistenceReaderKey where Self == AppStorageKey<Double> {
  public static var lastReviewRequest: Self {
    AppStorageKey("last-review-request-timeinterval")
  }
}
