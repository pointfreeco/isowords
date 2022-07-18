import Foundation

extension UserDefaultsClient {
  public static func live(
    userDefaults: UserDefaults = UserDefaults(suiteName: "group.isowords")!
  ) -> Self {
    Self(
      boolForKey: userDefaults.bool(forKey:),
      dataForKey: userDefaults.data(forKey:),
      doubleForKey: userDefaults.double(forKey:),
      integerForKey: userDefaults.integer(forKey:),
      remove: { userDefaults.removeObject(forKey: $0) },
      setBool: { userDefaults.set($0, forKey: $1) },
      setData: { userDefaults.set($0, forKey: $1) },
      setDouble: { userDefaults.set($0, forKey: $1) },
      setInteger: { userDefaults.set($0, forKey: $1) }
    )
  }
}
