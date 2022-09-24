import Dependencies
import SharedModels
import XCTestDynamicOverlay

extension DependencyValues {
  public var dictionary: DictionaryClient {
    get { self[DictionaryClient.self] }
    set { self[DictionaryClient.self] = newValue }
  }
}

extension DictionaryClient: TestDependencyKey {
  public static let previewValue = Self.everyString

  public static let testValue = Self(
    contains: XCTUnimplemented("\(Self.self).contains", placeholder: false),
    load: XCTUnimplemented("\(Self.self).load", placeholder: false),
    lookup: XCTUnimplemented("\(Self.self).lookup"),
    randomCubes: XCTUnimplemented("\(Self.self).randomCubes", placeholder: .mock),
    unload: XCTUnimplemented("\(Self.self).unload")
  )
}

extension DictionaryClient {
  public static let everyString = Self(
    contains: { word, _ in word.count >= 3 },
    load: { _ in true },
    lookup: nil,
    randomCubes: { _ in fatalError() },
    unload: { _ in }
  )
}
