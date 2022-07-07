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
      remove: { key in
        .fireAndForget {
          userDefaults.removeObject(forKey: key)
        }
      },
      removeAsync: { userDefaults.removeObject(forKey: $0) },
      setBool: { value, key in
        .fireAndForget {
          userDefaults.set(value, forKey: key)
        }
      },
      setBoolAsync: { userDefaults.set($0, forKey: $1) },
      setData: { data, key in
        .fireAndForget {
          userDefaults.set(data, forKey: key)
        }
      },
      setDataAsync: { userDefaults.set($0, forKey: $1) },
      setDouble: { value, key in
        .fireAndForget {
          userDefaults.set(value, forKey: key)
        }
      },
      setDoubleAsync: { userDefaults.set($0, forKey: $1) },
      setInteger: { value, key in
        .fireAndForget {
          userDefaults.set(value, forKey: key)
        }
      },
      setIntegerAsync: { userDefaults.set($0, forKey: $1) }
    )
  }
}
