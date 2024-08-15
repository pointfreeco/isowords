import CustomDump
import Foundation
import Overture
import XCTest

func assertBackwardsCompatibleCodable<A>(
  value: A,
  json: Any,
  decoder: JSONDecoder = decoder,
  encoder: JSONEncoder = encoder,
  file: StaticString = #filePath,
  line: UInt = #line
) throws where A: Codable & Equatable {

  let expectedData = try JSONSerialization.data(withJSONObject: json, options: [.sortedKeys])
  let decodedValue = try decoder.decode(A.self, from: expectedData)

  expectNoDifference(
    value,
    decodedValue,
    "Value decoded from JSON does not match expected value",
    file: file,
    line: line
  )

  let encodedDecodedValue = try encoder.encode(decodedValue)
  let reSerializedJson = try JSONSerialization.jsonObject(with: encodedDecodedValue)

  XCTAssertTrue(
    `is`(json, subsetOf: reSerializedJson),
    "Reserialization of encoded value is not a superset of json provided.",
    file: file,
    line: line
  )
}

func `is`(_ lhs: Any, subsetOf rhs: Any) -> Bool {
  switch (lhs, rhs) {
  case is (Void, Void):
    return true

  case let (lhs as Bool, rhs as Bool):
    return lhs == rhs
  case let (lhs as Int, rhs as Int):
    return lhs == rhs
  case let (lhs as Int8, rhs as Int8):
    return lhs == rhs
  case let (lhs as Int16, rhs as Int16):
    return lhs == rhs
  case let (lhs as Int32, rhs as Int32):
    return lhs == rhs
  case let (lhs as Int64, rhs as Int64):
    return lhs == rhs
  case let (lhs as UInt, rhs as UInt):
    return lhs == rhs
  case let (lhs as UInt8, rhs as UInt8):
    return lhs == rhs
  case let (lhs as UInt16, rhs as UInt16):
    return lhs == rhs
  case let (lhs as UInt32, rhs as UInt32):
    return lhs == rhs
  case let (lhs as UInt64, rhs as UInt64):
    return lhs == rhs
  case let (lhs as Float, rhs as Float):
    return lhs == rhs
  case let (lhs as Double, rhs as Double):
    return lhs == rhs
  case let (lhs as String, rhs as String):
    return lhs == rhs

  case let (lhs as [String: Any], rhs as [String: Any]):
    return lhs.keys.reduce(true) { isEqual, key in
      isEqual
        && zip(lhs[key], rhs[key]).map(`is`(_:subsetOf:)) == true
    }

  case let (lhs as [Any], rhs as [Any]):
    return lhs.count == rhs.count
      && lhs.indices.reduce(true) { isEqual, index in
        isEqual && `is`(lhs[index], subsetOf: rhs[index])
      }

  default:
    return false
  }
}

class BackwardsCompatibilityTestHelpersTests: XCTestCase {
  func testIsSubsetOf() {
    XCTAssertTrue(`is`([1], subsetOf: [1]))
    XCTAssertTrue(`is`(["id": 1], subsetOf: ["id": 1, "name": "Blob"] as [String : Any]))
    XCTAssertTrue(
      `is`(
        ["id": 1, "friends": [["id": 1]]] as [String : Any],
        subsetOf: ["id": 1, "friends": [["id": 1, "name": "Blob"] as [String : Any]]] as [String : Any]))

    XCTAssertFalse(`is`([1], subsetOf: [1, 2]))
    XCTAssertFalse(`is`(["id": 1], subsetOf: ["name": "Blob"]))
    XCTAssertFalse(
      `is`(["id": 1, "friends": [["id": 1]]] as [String : Any], subsetOf: ["id": 1, "friends": [["name": "Blob"]]] as [String : Any]))
  }
}

let decoder = JSONDecoder()
let encoder = update(JSONEncoder()) {
  $0.outputFormatting = [.prettyPrinted, .sortedKeys]
}
