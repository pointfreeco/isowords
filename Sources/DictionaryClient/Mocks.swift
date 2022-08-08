import SharedModels
import XCTestDynamicOverlay

extension DictionaryClient {
  public static let everyString = Self(
    contains: { word, _ in word.count >= 3 },
    load: { _ in true },
    lookup: nil,
    randomCubes: { _ in fatalError() },
    unload: { _ in }
  )
}

extension DictionaryClient {
  public static let unimplemented = Self(
    contains: XCTUnimplemented("\(Self.self).contains", placeholder: false),
    load: XCTUnimplemented("\(Self.self).load", placeholder: false),
    lookup: XCTUnimplemented("\(Self.self).lookup"),
    randomCubes: XCTUnimplemented("\(Self.self).randomCubes", placeholder: .mock),
    unload: XCTUnimplemented("\(Self.self).unload")
  )
}
