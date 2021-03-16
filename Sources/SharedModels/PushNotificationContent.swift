public enum PushNotificationContent: Equatable, Codable {
  case dailyChallengeEndsSoon
  case dailyChallengeReport

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    if container.contains(.dailyChallengeEndsSoon) {
      self = .dailyChallengeEndsSoon
    } else if container.contains(.dailyChallengeReport) {
      self = .dailyChallengeReport
    } else {
      throw
        DecodingError
        .dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Data corrupted"))
    }
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    switch self {
    case .dailyChallengeEndsSoon:
      try container.encode(true, forKey: .dailyChallengeEndsSoon)

    case .dailyChallengeReport:
      try container.encode(true, forKey: .dailyChallengeReport)
    }
  }

  public enum CodingKeys: String, Codable, CodingKey {
    case dailyChallengeEndsSoon
    case dailyChallengeReport
  }
}
