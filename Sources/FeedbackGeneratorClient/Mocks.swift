import XCTestDynamicOverlay

extension FeedbackGeneratorClient {
  public static let unimplemented = Self(
    prepare: XCTUnimplemented("\(Self.self).prepare"),
    selectionChanged: XCTUnimplemented("\(Self.self).selectionChanged")
  )

  public static let noop = Self(
    prepare: {},
    selectionChanged: {}
  )
}
