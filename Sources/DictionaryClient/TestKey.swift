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
    contains: unimplemented("\(Self.self).contains", placeholder: false),
    load: unimplemented("\(Self.self).load", placeholder: false),
    lookup: unimplemented("\(Self.self).lookup"),
    randomCubes: unimplemented("\(Self.self).randomCubes", placeholder: .mock),
    unload: unimplemented("\(Self.self).unload")
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
