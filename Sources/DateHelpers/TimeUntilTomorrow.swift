import Foundation
import SwiftUI

public func timeUntilTomorrow(now: Date) -> TimeInterval {
  var gmtCalendar = Calendar.current
  gmtCalendar.timeZone = TimeZone(secondsFromGMT: 0)!

  let startOfNextDay = gmtCalendar.nextDate(
    after: now,
    matching: DateComponents(hour: 0, minute: 0),
    matchingPolicy: .nextTimePreservingSmallerComponents
  )!
  return startOfNextDay.timeIntervalSince(now)
}

public func timeDescriptionUntilTomorrow(now: Date) -> LocalizedStringKey {
  let time = timeUntilTomorrow(now: now)

  if time <= 60 {
    let seconds = Int(time)
    return seconds == 1
      ? "\(seconds) second"
      : "\(seconds) seconds"
  } else if time <= 60 * 60 {
    let minutes = Int(time / 60)
    return minutes == 1
      ? "\(minutes) minute"
      : "\(minutes) minutes"
  } else {
    let hours = Int(time / 60 / 60)
    return hours == 1
      ? "\(hours) hour"
      : "\(hours) hours"
  }
}
