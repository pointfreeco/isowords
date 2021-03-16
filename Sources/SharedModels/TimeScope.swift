public enum TimeScope: String, CaseIterable, Codable {
  case allTime
  case lastDay
  case lastWeek
}

#if canImport(SwiftUI)
  import SwiftUI

  extension TimeScope {
    public var displayTitle: LocalizedStringKey {
      switch self {
      case .lastDay:
        return "Past day"
      case .lastWeek:
        return "Past week"
      case .allTime:
        return "All time"
      }
    }
  }
#endif
