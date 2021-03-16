import Foundation

// NB: Dynamically load XCTest to prevent leaking its symbols into our library code.
public func XCTFail(_ message: String) {
  #if canImport(ObjectiveC)
    guard
      let currentTestCase = _XCTCurrentTestCase(),
      let XCTIssue = NSClassFromString("XCTIssue")
        as Any as? NSObjectProtocol,
      let alloc = XCTIssue.perform(NSSelectorFromString("alloc"))?
        .takeUnretainedValue(),
      let issue =
        alloc
        .perform(
          Selector(("initWithType:compactDescription:")), with: 0, with: message
        )?
        .takeUnretainedValue()
    else { return }

    _ = currentTestCase.perform(Selector(("recordIssue:")), with: issue)
  #endif
}
