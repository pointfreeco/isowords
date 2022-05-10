import XCTestDebugSupport
import XCTestDynamicOverlay

extension FeedbackGeneratorClient {
  #if DEBUG
    public static let failing = Self(
      prepare: { XCTFail("\(Self.self).prepare is unimplemented") },
      selectionChanged: { XCTFail("\(Self.self).selectionChanged is unimplemented") }
    )
  #endif

  public static let noop = Self(
    prepare: { },
    selectionChanged: { }
  )
}
