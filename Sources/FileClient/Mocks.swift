import ComposableArchitecture
import Foundation
import XCTestDebugSupport
import XCTestDynamicOverlay

extension FileClient {
  public static let noop = Self(
    delete: { _ in },
    load: { _ in throw CancellationError() },
    save: { _, _ in }
  )

  #if DEBUG
    public static let failing = Self(
      delete: XCTUnimplemented("\(Self.self).deleteAsync"),
      load: XCTUnimplemented("\(Self.self).loadAsync"),
      save: XCTUnimplemented("\(Self.self).saveAsync")
    )
  #endif

  public mutating func override<A: Encodable>(load file: String, _ data: A) {
    let fulfill = expectation(description: "FileClient.load(\(file))")
    self.load = { @Sendable [self] in
      if $0 == file {
        fulfill()
        return try JSONEncoder().encode(data)
      } else {
        return try await load($0)
      }
    }
  }
}
