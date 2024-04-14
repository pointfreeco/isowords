import ComposableArchitecture
import Foundation
import Tagged

public struct Build: Equatable, Sendable {
  public var gitSha = Bundle.main.infoDictionary?["GitSHA"] as? String ?? ""
  public var number = Number(
    rawValue: (Bundle.main.infoDictionary?["CFBundleVersion"] as? String)
      .flatMap(Int.init)
      ?? 0)
  public init() {}

  public typealias Number = Tagged<((), number: ()), Int>
}

extension PersistenceReaderKey where Self == InMemoryKey<Build> {
  public static var build: Self {
    inMemory("build")
  }
}
