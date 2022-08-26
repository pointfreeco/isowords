import ComposableArchitecture

extension DependencyValues {
  public var feedbackGenerator: FeedbackGeneratorClient {
    get { self[FeedbackGeneratorClientKey.self] }
    set { self[FeedbackGeneratorClientKey.self] = newValue }
  }

  private enum FeedbackGeneratorClientKey: DependencyKey {
    static let liveValue = FeedbackGeneratorClient.live
    static let testValue = FeedbackGeneratorClient.unimplemented
  }
}

public struct FeedbackGeneratorClient {
  public var prepare: @Sendable () async -> Void
  public var selectionChanged: @Sendable () async -> Void
}
