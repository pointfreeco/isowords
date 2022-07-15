import ComposableArchitecture

public struct FeedbackGeneratorClient {
  @available(*, deprecated) public var prepare: () -> Effect<Never, Never>
  public var prepareAsync: @Sendable () async -> Void
  @available(*, deprecated) public var selectionChanged: () -> Effect<Never, Never>
  public var selectionChangedAsync: @Sendable () async -> Void
}
