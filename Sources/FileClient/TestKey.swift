//import Dependencies
//import Foundation
//import XCTestDebugSupport
//import XCTestDynamicOverlay
//
//extension DependencyValues {
//  public var fileClient: FileClient {
//    get { self[FileClient.self] }
//    set { self[FileClient.self] = newValue }
//  }
//}
//
//extension FileClient: TestDependencyKey {
//  public static let previewValue = Self.noop
//
//  public static let testValue = Self(
//    delete: XCTUnimplemented("\(Self.self).deleteAsync"),
//    load: XCTUnimplemented("\(Self.self).loadAsync"),
//    save: XCTUnimplemented("\(Self.self).saveAsync")
//  )
//}
//
//extension FileClient {
//  public static let noop = Self(
//    delete: { _ in },
//    load: { _ in throw CancellationError() },
//    save: { _, _ in }
//  )
//
//  public mutating func override<A: Encodable>(load file: String, _ data: A) {
//    let fulfill = expectation(description: "FileClient.load(\(file))")
//    self.load = { @Sendable[self] in
//      if $0 == file {
//        fulfill()
//        return try JSONEncoder().encode(data)
//      } else {
//        return try await load($0)
//      }
//    }
//  }
//}
