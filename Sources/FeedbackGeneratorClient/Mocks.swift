import XCTestDebugSupport

extension FeedbackGeneratorClient {
  #if DEBUG
    public static let failing = Self(
      prepare: { .failing("\(Self.self).prepare is unimplemented") },
      selectionChanged: { .failing("\(Self.self).selectionChanged is unimplemented") }
    )
  #endif

  public static let noop = Self(
    prepare: { .none },
    selectionChanged: { .none }
  )
}
