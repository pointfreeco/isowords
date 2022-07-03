import ComposableArchitecture

public struct FeedbackGeneratorClient {
  public var prepare: () -> Effect<Never, Never>
  public var prepareAsync: @Sendable () async -> Void
  public var selectionChanged: () -> Effect<Never, Never>
  public var selectionChangedAsync: @Sendable () async -> Void
}
