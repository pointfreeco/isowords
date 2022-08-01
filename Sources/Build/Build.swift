import Foundation
import Tagged

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
    public static let unimplemented = Self(
      gitSha: XCTUnimplemented("\(Self.self).gitSha"),
      number: XCTUnimplemented("\(Self.self).number")
    )
  }
#endif
