import Foundation

func _XCTCurrentTestCase() -> AnyObject? {
  #if canImport(ObjectiveC)
    guard
      let XCTestObservationCenter = NSClassFromString("XCTestObservationCenter")
        as Any as? NSObjectProtocol,
      String(describing: XCTestObservationCenter) != "<null>",
      let shared = XCTestObservationCenter.perform(Selector(("sharedTestObservationCenter")))?
        .takeUnretainedValue(),
      let observers = shared.perform(Selector(("observers")))?
        .takeUnretainedValue() as? [AnyObject],
      let observer =
        observers
        .first(where: { NSStringFromClass(type(of: $0)) == "XCTestMisuseObserver" }),
      let currentTestCase = observer.perform(Selector(("currentTestCase")))?
        .takeUnretainedValue()
    else { return nil }
    return currentTestCase
  #else
    return nil
  #endif
}
