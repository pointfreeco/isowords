import Dependencies
import Foundation
import XCTestDebugSupport
import XCTestDynamicOverlay

extension DependencyValues {
  public var userSettingsClient: UserSettingsClient {
    get { self[UserSettingsClient.self] }
    set { self[UserSettingsClient.self] = newValue }
  }
}

extension UserSettingsClient: TestDependencyKey {
  public static let previewValue = Self.noop

  public static let testValue = Self(
    delete: XCTUnimplemented("\(Self.self).deleteAsync"),
    load: XCTUnimplemented("\(Self.self).loadAsync"),
    save: XCTUnimplemented("\(Self.self).saveAsync"),
    loadSavedGames: XCTUnimplemented("\(Self.self).loadSavedGames"),
    saveGames: XCTUnimplemented("\(Self.self).saveGames")
  )
}

extension UserSettingsClient {
  public static let noop = Self(
    delete: { _ in },
    load: { _ in throw CancellationError() },
    save: { _, _ in },
    loadSavedGames: { .init() },
    saveGames: { _ in }
  )

  public mutating func override<A: Encodable>(load file: String, _ data: A) {
    let fulfill = expectation(description: "UserSettingsClient.load(\(file))")
    self.load = { @Sendable[self] in
      if $0 == file {
        fulfill()
        return try JSONEncoder().encode(data)
      } else {
        return try await load($0)
      }
    }
  }
}
