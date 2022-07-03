import XCTestDebugSupport
import XCTestDynamicOverlay

extension FeedbackGeneratorClient {
  #if DEBUG
    public static let failing = Self(
      prepare: { .failing("\(Self.self).prepare is unimplemented") },
      prepareAsync: XCTUnimplemented("\(Self.self).prepareAsync"),
      selectionChanged: { .failing("\(Self.self).selectionChanged is unimplemented") },
      selectionChangedAsync: XCTUnimplemented("\(Self.self).selectionChangedAsync")
    )
  #endif

  public static let noop = Self(
    prepare: { .none },
    prepareAsync: {},
    selectionChanged: { .none },
    selectionChangedAsync: {}
  )
}
