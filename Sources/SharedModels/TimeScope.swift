public enum TimeScope: String, CaseIterable, Codable {
  case allTime
  case lastDay
  case lastWeek
  case interesting
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
