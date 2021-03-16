import DatabaseClient
import Either
import HttpPipeline
import Prelude
import SharedModels

public struct FetchLeaderboardRequest {
  let currentPlayer: Player
  let database: DatabaseClient
  let gameMode: GameMode
  let language: Language
  let timeScope: TimeScope

  public init(
    currentPlayer: Player,
    database: DatabaseClient,
    gameMode: GameMode,
    language: Language,
    timeScope: TimeScope
  ) {
    self.currentPlayer = currentPlayer
    self.database = database
    self.gameMode = gameMode
    self.language = language
    self.timeScope = timeScope
  }
}

public func fetchLeaderboardMiddleware(
  _ conn: Conn<StatusLineOpen, FetchLeaderboardRequest>
) -> IO<Conn<HeadersOpen, Either<ApiError, FetchLeaderboardResponse>>> {

  let request = conn.data

  return request.database
    .fetchRankedLeaderboardScores(
      .init(
        gameMode: request.gameMode,
        language: request.language,
        playerId: request.currentPlayer.id,
        timeScope: request.timeScope
      )
    )
    .map(FetchLeaderboardResponse.init(entries:))
    .run
    .flatMap { errorOrResponse in
      switch errorOrResponse {
      case let .left(error):
        return conn.map(const(.left(ApiError(error: error))))
          |> writeStatus(.internalServerError)

      case let .right(response):
        return conn.map(const(.right(response)))
          |> writeStatus(.ok)
      }
    }
}
