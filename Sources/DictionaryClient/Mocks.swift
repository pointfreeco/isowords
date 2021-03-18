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

  public static let failing = Self(
    contains: { _, _ in XCTFail("\(Self.self).contains is unimplemented")
      return false
    },
    load: { _ in XCTFail("\(Self.self).load is unimplemented")
      return false
    },
    lookup: { _, _ in XCTFail("\(Self.self).lookup is unimplemented")
      return nil
    },
    randomCubes: { _ in XCTFail("\(Self.self).randomCubes is unimplemented")
      return .mock
    },
    unload: { _ in XCTFail("\(Self.self).unload is unimplemented") }
  )
}
