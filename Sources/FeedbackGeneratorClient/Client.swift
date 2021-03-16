import ComposableArchitecture

public struct FeedbackGeneratorClient {
  public var prepare: () -> Effect<Never, Never>
  public var selectionChanged: () -> Effect<Never, Never>
}
