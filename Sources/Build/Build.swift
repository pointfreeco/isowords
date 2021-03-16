import Foundation
import XCTestDebugSupport

public struct Build {
  public var gitSha: () -> String
  public var number: () -> Int

  public init(
    gitSha: @escaping () -> String,
    number: @escaping () -> Int
  ) {
    self.gitSha = gitSha
    self.number = number
  }

  public static let live = Self(
    gitSha: { Bundle.main.infoDictionary?["GitSHA"] as? String ?? "" },
    number: {
      (Bundle.main.infoDictionary?["CFBundleVersion"] as? String)
        .flatMap(Int.init)
        ?? 0
    }
  )

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

  public static let noop = Self(
    gitSha: { "deadbeef" },
    number: { 0 }
  )
}
