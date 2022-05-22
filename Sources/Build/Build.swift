import ComposableArchitecture
import Foundation
import Tagged

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

public struct Build {
  public var gitSha: () -> String
  public var number: () -> Number

  public typealias Number = Tagged<((), number: ()), Int>

  public init(
    gitSha: @escaping () -> String,
    number: @escaping () -> Number
  ) {
    self.gitSha = gitSha
    self.number = number
  }

  public static let live = Self(
    gitSha: { Bundle.main.infoDictionary?["GitSHA"] as? String ?? "" },
    number: {
      .init(
        rawValue: (Bundle.main.infoDictionary?["CFBundleVersion"] as? String)
          .flatMap(Int.init)
          ?? 0
      )
    }
  )

  public static let noop = Self(
    gitSha: { "deadbeef" },
    number: { 0 }
  )
}

#if DEBUG
  import XCTestDynamicOverlay

  extension Build {
    public static let failing = Self(
      gitSha: {
        XCTFail("\(Self.self).gitSha is unimplemented")
        return ""
      },
      number: {
        XCTFail("\(Self.self).number is unimplemented")
        return 0
      }
    )
  }
#endif
