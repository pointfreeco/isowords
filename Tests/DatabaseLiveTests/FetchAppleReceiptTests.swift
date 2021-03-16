import Overture
import PostgresKit
import XCTest

@testable import DatabaseClient
@testable import DatabaseLive
@testable import SharedModels

class FetchAppleReceiptTests: DatabaseTestCase {
  func testFetchAppleReceipt() throws {
    let player = try self.database.insertPlayer(.blob)
      .run.perform().unwrap()

    try self.database.updateAppleReceipt(player.id, .mock)
      .run.perform().unwrap()

    let receipt = try XCTUnwrap(
      self.database.fetchAppleReceipt(player.id)
        .run.perform().unwrap()
    )

    XCTAssertEqual(
      receipt,
      .init(
        createdAt: receipt.createdAt,
        id: receipt.id,
        playerId: player.id,
        receipt: .mock
      )
    )
  }
}
