import ComposableArchitecture
import Foundation
import XCTestDebugSupport
import XCTestDynamicOverlay

extension FileClient {
  public static let noop = Self(
    delete: { _ in .none },
    deleteAsync: { _ in },
    load: { _ in .none },
    loadAsync: { _ in throw CancellationError() },
    save: { _, _ in .none },
    saveAsync: { _, _ in }
  )

  #if DEBUG
    public static let failing = Self(
      delete: { .failing("\(Self.self).delete(\($0)) is unimplemented") },
      deleteAsync: XCTUnimplemented("\(Self.self).deleteAsync"),
      load: { .failing("\(Self.self).load(\($0)) is unimplemented") },
      loadAsync: XCTUnimplemented("\(Self.self).loadAsync"),
      save: { file, _ in .failing("\(Self.self).save(\(file)) is unimplemented") },
      saveAsync: XCTUnimplemented("\(Self.self).saveAsync")
    )
  #endif

  public mutating func override<A>(
    load file: String, _ data: Effect<A, Error>
  )
  where A: Encodable {
    let fulfill = expectation(description: "FileClient.load(\(file))")
    self.load = { [self] in
      if $0 == file {
        fulfill()
        return data.tryMap { try JSONEncoder().encode($0) }.eraseToEffect()
      } else {
        return self.load($0)
      }
    }
  }
}
