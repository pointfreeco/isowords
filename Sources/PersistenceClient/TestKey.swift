import Dependencies
import Foundation
import XCTestDebugSupport
import XCTestDynamicOverlay

extension DependencyValues {
  public var persistenceClient: PersistenceClient {
    get { self[PersistenceClient.self] }
    set { self[PersistenceClient.self] = newValue }
  }
}

extension PersistenceClient: TestDependencyKey {
  public static let previewValue = Self.noop

  public static let testValue = Self(
    userSettings: XCTUnimplemented("\(Self.self).userSettings"),
    setUserSettings: XCTUnimplemented("\(Self.self).setUserSettings"),
    savedGames: XCTUnimplemented("\(Self.self).savedGames"),
    setSavedGames: XCTUnimplemented("\(Self.self).setSavedGames"),
    deleteSavedGames: XCTUnimplemented("\(Self.self).deleteSavedGames")
  )
}

extension PersistenceClient {
  public static let noop = Self(
    userSettings: { .init() },
    setUserSettings: { _ in },
    savedGames: { .init() },
    setSavedGames: { _ in },
    deleteSavedGames: {}
  )
}
