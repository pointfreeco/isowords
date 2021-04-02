import DatabaseClient
import DictionaryClient
import Either
import HttpPipeline
import Prelude
import SharedModels

public struct SubmitDemoGameRequest {
  public let database: DatabaseClient
  public let dictionary: DictionaryClient
  public let submitRequest: ServerRoute.Demo.SubmitRequest

  public init(
    database: DatabaseClient,
    dictionary: DictionaryClient,
    submitRequest: ServerRoute.Demo.SubmitRequest
  ) {
    self.database = database
    self.dictionary = dictionary
    self.submitRequest = submitRequest
  }
}

public func submitDemoGameMiddleware(
  _ conn: Conn<StatusLineOpen, SubmitDemoGameRequest>
) -> IO<Conn<HeadersOpen, Either<ApiError, LeaderboardScoreResult>>> {

  sequence(
    TimeScope.soloCases.map { timeScope in
      conn.data.database.fetchLeaderboardSummary(
        .init(
          gameMode: conn.data.submitRequest.gameMode,
          timeScope: timeScope,
          type: .anonymous(score: conn.data.submitRequest.score)
        )
      )
      .map { rank in (timeScope: timeScope, rank: rank) }
    }
  )
  .map { LeaderboardScoreResult(ranks: Dictionary($0, uniquingKeysWith: { $1 })) }
  .run
  .flatMap { errorOrResult in
    switch errorOrResult {
    case let .left(error):
      return conn.map(const(.left(ApiError(error: error))))
        |> writeStatus(.badRequest)

    case let .right(result):
      return conn.map(const(.right(result)))
        |> writeStatus(.ok)
    }
  }
}
