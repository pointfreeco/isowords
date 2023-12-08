import Dependencies

extension DependencyValues {
  public var serverConfig: ServerConfigClient {
    get { self[ServerConfigClient.self] }
    set { self[ServerConfigClient.self] = newValue }
  }
}

extension ServerConfigClient: TestDependencyKey {
  public static let previewValue = Self.noop
  public static let testValue = Self()
}

extension ServerConfigClient {
  public static let noop = Self(
    config: { .init() },
    refresh: { try await Task.never() }
  )
}
