public enum TimeScope: String, CaseIterable, Codable, Sendable {
  case allTime
  case lastDay
  case lastWeek
  case interesting

  public static let soloCases: [Self] = [.allTime, .lastDay, .lastWeek]
}

#if canImport(SwiftUI)
  import SwiftUI

  extension TimeScope {
    public var displayTitle: LocalizedStringKey {
      switch self {
      case .allTime:
        return "All time"
      case .lastDay:
        return "Past day"
      case .lastWeek:
        return "Past week"
      case .interesting:
        return "Interesting"
      }
    }
  }
#endif
