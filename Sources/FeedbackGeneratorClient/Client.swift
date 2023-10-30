import DependenciesMacros

@DependencyClient
public struct FeedbackGeneratorClient {
  public var prepare: @Sendable () async -> Void
  public var selectionChanged: @Sendable () async -> Void
}
