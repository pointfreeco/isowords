import DictionaryClient
import DictionaryFileClient
import SharedModels
import XCTest

class DictionaryClientTests: XCTestCase {
  func testPrepare() {
    let client = DictionaryClient.file()
    XCTAssertTrue(try client.load(.en))
    XCTAssertTrue(client.contains("HELLO", .en))
  }
}
