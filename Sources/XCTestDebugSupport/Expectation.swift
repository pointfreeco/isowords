import Foundation

// NB: Dynamically load XCTest to prevent leaking its symbols into our library code.
public func expectation(description: String = "") -> () -> Void {
  #if canImport(ObjectiveC)
    guard
      let currentTestCase = _XCTCurrentTestCase(),
      let expectation =
        currentTestCase
        .perform(Selector(("expectationWithDescription:")), with: description)?
        .takeUnretainedValue()
    else {
      return {}
    }
    //  expectation.setValue(false, forKey: "assertForOverFulfill")
    var isFulfilled = false
    return {
      if !isFulfilled {
        _ = expectation.perform(Selector(("fulfill")))
        _ =
          currentTestCase
          .perform(Selector(("waitForExpectations:timeout:")), with: [expectation], with: 0)
        isFulfilled = true
      }
    }
  #else
    return {}
  #endif
}

public func expect<R>(action: @escaping () -> R) -> () -> R {
  #if canImport(ObjectiveC)
    let fulfill = expectation(description: "should be called")
    return {
      let result = action()
      fulfill()
      return result
    }
  #else
    return { fatalError() }
  #endif
}

public func expect<A, R>(action: @escaping (A) -> R) -> (A) -> R {
  #if canImport(ObjectiveC)
    let fulfill = expectation(description: "should be called")
    return {
      let result = action($0)
      fulfill()
      return result
    }
  #else
    return { _ in fatalError() }
  #endif
}
