import XCTest

public func XCTUnwrap<T>(
  _ expression: @autoclosure () throws -> T?,
  _ message: @autoclosure () -> String = "",
  file: StaticString = #filePath,
  line: UInt = #line,
  block: (inout T) throws -> Void
) throws -> T {
  var t = try XCTUnwrap(expression(), message(), file: file, line: line)
  try block(&t)
  return t
}

public func XCTUnwrap<T>(
  _ value: inout T?,
  _ message: @autoclosure () -> String = "",
  file: StaticString = #filePath,
  line: UInt = #line,
  block: (inout T) throws -> Void
) throws {
  var t = try XCTUnwrap(value, message(), file: file, line: line)
  try block(&t)
  value = t
}
