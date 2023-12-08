import Dependencies
import DependenciesMacros
import Foundation
import Tagged

@DependencyClient
public struct Build {
  public var gitSha: () -> String = { "deadbeef" }
  public var number: () -> Number = { 0 }

  public typealias Number = Tagged<((), number: ()), Int>
}

extension DependencyValues {
  public var build: Build {
    get { self[Build.self] }
    set { self[Build.self] = newValue }
  }
}

extension Build: TestDependencyKey {
  public static let previewValue = Self.noop
  public static let testValue = Self()
}

extension Build: DependencyKey {
  public static let liveValue = Self(
    gitSha: { Bundle.main.infoDictionary?["GitSHA"] as? String ?? "" },
    number: {
      .init(
        rawValue: (Bundle.main.infoDictionary?["CFBundleVersion"] as? String)
          .flatMap(Int.init)
          ?? 0
      )
    }
  )
}

extension Build {
  public static let noop = Self(
    gitSha: { "deadbeef" },
    number: { 0 }
  )
}
