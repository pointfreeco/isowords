import ApiClient
import Build
import ComposableArchitecture
import ServerConfigClient
import UIApplicationClient
import UserDefaultsClient

extension DependencyValues {
  public var apiClient: ApiClient {
    get { self[ApiClientKey.self] }
    set { self[ApiClientKey.self] = newValue }
  }

  private enum ApiClientKey: DependencyKey {
    static let testValue = ApiClient.failing
  }
}

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

extension DependencyValues {
  public var build: Build {
    get { self[BuildKey.self] }
    set { self[BuildKey.self] = newValue }
  }

  private enum BuildKey: LiveDependencyKey {
    static let liveValue = Build.live
    static let testValue = Build.failing
  }
}

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

