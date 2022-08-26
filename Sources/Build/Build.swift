import Dependencies
import Foundation
import Tagged
import XCTestDynamicOverlay

extension DependencyValues {
  public var build: Build {
    get { self[BuildKey.self] }
    set { self[BuildKey.self] = newValue }
  }

  private enum BuildKey: DependencyKey {
    static let liveValue = Build.live
    static let testValue = Build.unimplemented
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

extension Build {
  public static let unimplemented = Self(
    gitSha: XCTUnimplemented("\(Self.self).gitSha", placeholder: "deadbeef"),
    number: XCTUnimplemented("\(Self.self).number", placeholder: 0)
  )
}
