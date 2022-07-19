public enum GameMode: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
  case timed
  case unlimited

  public var id: Self { self }

  public var seconds: Int {
    switch self {
    case .timed:
      return 3 * 60
    case .unlimited:
      return .max
    }
  }

  public static let dailyChallengeModes = Self.allCases.filter { gameMode in
    switch gameMode {
    case .timed: return true
    case .unlimited: return true
    }
  }
}
