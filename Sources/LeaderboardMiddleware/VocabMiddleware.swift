import DatabaseClient
import Either
import HttpPipeline
import Overture
import Prelude
import SharedModels

public struct FetchVocabLeaderboardRequest {
  let currentPlayer: Player
  let database: DatabaseClient
  let language: Language
  let timeScope: TimeScope

  public init(
    currentPlayer: Player,
    database: DatabaseClient,
    language: Language,
    timeScope: TimeScope
  ) {
    self.currentPlayer = currentPlayer
    self.database = database
    self.language = language
    self.timeScope = timeScope
  }
}

public func fetchVocabLeaderboard(
  _ conn: Conn<StatusLineOpen, FetchVocabLeaderboardRequest>
) -> IO<Conn<HeadersOpen, Either<ApiError, [FetchVocabLeaderboardResponse.Entry]>>> {

  let request = conn.data

  return request.database.fetchVocabLeaderboard(
    request.language,
    request.currentPlayer,
    request.timeScope
  )
  .run
  .flatMap { errorOrEntries in
    switch errorOrEntries {
    case let .left(error):
      return conn.map(const(.left(ApiError(error: error))))
        |> writeStatus(.internalServerError)

    case let .right(entries):
      return conn.map(const(.right(entries)))
        |> writeStatus(.ok)
    }
  }
}

public struct FetchVocabWordRequest {
  let database: DatabaseClient
  let wordId: Word.Id

  public init(
    database: DatabaseClient,
    wordId: Word.Id
  ) {
    self.database = database
    self.wordId = wordId
  }
}

public func fetchVocabWord(
  _ conn: Conn<StatusLineOpen, FetchVocabWordRequest>
) -> IO<Conn<HeadersOpen, Either<ApiError, FetchVocabWordResponse>>> {

  let request = conn.data

  return request.database.fetchVocabLeaderboardWord(request.wordId)
    .run
    .flatMap { errorOrResponse in
      switch errorOrResponse {
      case let .left(error):
        return conn.map(const(.left(ApiError(error: error))))
          |> writeStatus(.badRequest)

      case let .right(response):
        return conn.map(const(.right(response)))
          |> writeStatus(.ok)
      }
    }
}
