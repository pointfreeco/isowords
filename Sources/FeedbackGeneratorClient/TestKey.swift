import Dependencies
import XCTestDynamicOverlay

extension DependencyValues {
  public var feedbackGenerator: FeedbackGeneratorClient {
    get { self[FeedbackGeneratorClient.self] }
    set { self[FeedbackGeneratorClient.self] = newValue }
  }
}

extension FeedbackGeneratorClient: TestDependencyKey {
  public static let previewValue = Self.noop

  public static let testValue = Self(
    prepare: unimplemented("\(Self.self).prepare"),
    selectionChanged: unimplemented("\(Self.self).selectionChanged")
  )
}

extension FeedbackGeneratorClient {
  public static let noop = Self(
    prepare: {},
    selectionChanged: {}
  )
}
