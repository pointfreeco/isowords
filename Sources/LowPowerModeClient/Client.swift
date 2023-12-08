import DependenciesMacros

@DependencyClient
public struct LowPowerModeClient {
  public var start: @Sendable () async -> AsyncStream<Bool> = { .finished }
}
