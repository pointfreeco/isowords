import DictionaryClient
import DictionarySqliteClient
import SharedModels
import XCTest

class DictionaryClientTests: XCTestCase {
  func testPrepare() {
    let client = DictionaryClient.sqlite()
    XCTAssertTrue(client.contains("HELLO", .en))
  }

  func testHasPlayableWords() {
    XCTAssert(Puzzle.mock.hasPlayableWords(in: .sqlite()))

    let noWords = Puzzle.mock.map {
      $0.map {
        $0.map { _ in
          Cube(
            left: .init(letter: "A", side: .left),
            right: .init(letter: "A", side: .right),
            top: .init(letter: "A", side: .top)
          )
        }
      }
    }
    XCTAssert(!noWords.hasPlayableWords(in: .sqlite()))
  }
}
