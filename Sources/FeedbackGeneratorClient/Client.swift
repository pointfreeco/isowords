import ComposableArchitecture

public struct FeedbackGeneratorClient {
  public var prepare: () async -> Void
  public var selectionChanged: () async -> Void
}
