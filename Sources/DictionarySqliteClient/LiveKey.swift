import Dependencies
import DictionaryClient
import Foundation
import PuzzleGen
import SharedModels
import Sqlite

extension DictionaryClient: DependencyKey {
  public static let liveValue = Self.sqlite()
}

extension DictionaryClient {
  public static func sqlite(path: String? = nil) -> Self {
    var _db: Sqlite!
    var db: Sqlite {
      if _db == nil {
        let path =
          path
          ?? Bundle.module.path(forResource: "Words.en", ofType: "db", inDirectory: "Dictionaries")!
        _db = try? Sqlite(path: path)
      }
      return _db
    }

    return Self(
      contains: { string, language in
        (try? db.lookup(string: string)) == .some(true)
      },
      load: { _ in true },
      lookup: { string, language in
        (try? db.lookup(string: string)).map { $0 ? .word : .prefix }
      },
      randomCubes: { _ in PuzzleGen.randomCubes(for: isowordsLetter).run() },
      unload: { _ in }
    )
  }
}

extension Sqlite {
  func lookup(string: String) throws -> Bool? {
    guard
      let result = try self.run(
        """
        SELECT "word" = ?
        FROM "words"
        WHERE "word" >= ? AND "word" < ?
        LIMIT 1
        """,
        .text(string),
        .text(string),
        .text(string + "ZZ")
      )
      .first?.first
    else { return nil }

    return result == .integer(1)
  }
}
