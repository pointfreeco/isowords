public struct PushAuthorizationStatus: RawRepresentable, Codable, Equatable, Sendable {
  public static let authorized = Self(rawValue: 2)
  public static let denied = Self(rawValue: 1)
  public static let ephemeral = Self(rawValue: 4)
  public static let notDetermined = Self(rawValue: 0)
  public static let provisional = Self(rawValue: 3)

  public let rawValue: Int

  public init(rawValue: Int) {
    self.rawValue = rawValue
  }
}
