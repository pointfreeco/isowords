import DatabaseClient
import PostgresKit
import SharedModels
import XCTest

class DatabaseTestCase: XCTestCase {
  var database: DatabaseClient!
  var pool: EventLoopGroupConnectionPool<PostgresConnectionSource>!
  let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)

  override func setUp() {
    super.setUp()

    self.pool = EventLoopGroupConnectionPool(
      source: PostgresConnectionSource(
        configuration: PostgresConfiguration(
          url: "postgres://isowords:isowords@localhost:5432/isowords_test"
        )!
      ),
      on: self.eventLoopGroup
    )
    self.database = DatabaseClient.live(pool: self.pool)

    try! self.database.resetForTesting(pool: pool)
  }

  override func tearDown() {
    super.tearDown()
    try! self.pool.syncShutdownGracefully()
    try! self.eventLoopGroup.syncShutdownGracefully()
  }
}

func createPuzzlesIterator() -> UnfoldFirstSequence<ArchivablePuzzle> {
  sequence(first: ArchivablePuzzle.mock) {
    var puzzle = $0
    puzzle.2.2.2.left.letter = String(
      UnicodeScalar($0.2.2.2.left.letter.first!.unicodeScalars.first!.value + 1)!
    )
    return puzzle
  }
}
