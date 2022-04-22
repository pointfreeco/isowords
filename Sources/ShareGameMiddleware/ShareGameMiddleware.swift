import DatabaseClient
import Either
import EnvVars
import Foundation
import HttpPipeline
import Prelude
import ServerRouter
import SharedModels

public struct ShareGameRequest {
  public let completedGame: CompletedGame
  public let currentPlayer: Player
  public let database: DatabaseClient
  public let envVars: EnvVars
  public let router: ServerRouter

  public init(
    completedGame: CompletedGame,
    currentPlayer: Player,
    database: DatabaseClient,
    envVars: EnvVars,
    router: ServerRouter
  ) {
    self.completedGame = completedGame
    self.currentPlayer = currentPlayer
    self.database = database
    self.envVars = envVars
    self.router = router
  }
}

public func submitSharedGameMiddleware(
  _ conn: Conn<StatusLineOpen, ShareGameRequest>
) -> IO<Conn<HeadersOpen, Either<ApiError, SubmitSharedGameResponse>>> {

  let request = conn.data

  return conn.data.database.insertSharedGame(request.completedGame, request.currentPlayer)
    .run
    .flatMap { errorOrSharedGame in
      switch errorOrSharedGame {
      case let .left(error):
        return conn.map(const(.left(ApiError(error: error))))
          |> writeStatus(.badRequest)

      case let .right(sharedGame):
        return conn.map(
          const(
            .right(
              SubmitSharedGameResponse(
                code: sharedGame.code,
                id: sharedGame.id,
                url: conn.data.router
                  .baseURL(conn.data.envVars.baseUrl.absoluteString)
                  .url(for: .sharedGame(.show(sharedGame.code))).absoluteString
              )
            )
          )
        )
          |> writeStatus(.ok)
      }
    }
}

public struct FetchSharedGameRequest {
  public let code: SharedGame.Code
  public let database: DatabaseClient

  public init(
    code: SharedGame.Code,
    database: DatabaseClient
  ) {
    self.code = code
    self.database = database
  }
}

public func fetchSharedGameMiddleware(
  _ conn: Conn<StatusLineOpen, FetchSharedGameRequest>
) -> IO<Conn<HeadersOpen, Either<ApiError, SharedGameResponse>>> {

  conn.data.database.fetchSharedGame(conn.data.code)
    .run
    .flatMap { errorOrSharedGame in
      switch errorOrSharedGame {
      case let .left(error):
        return conn.map(const(.left(ApiError(error: error))))
          |> writeStatus(.badRequest)

      case let .right(sharedGame):
        return conn.map(
          const(
            .right(
              SharedGameResponse(
                code: sharedGame.code,
                id: sharedGame.id,
                gameMode: sharedGame.gameMode,
                language: sharedGame.language,
                moves: sharedGame.moves,
                puzzle: sharedGame.puzzle
              )
            )
          )
        )
          |> writeStatus(.ok)
      }
    }
}

public struct ShowSharedGameRequest {
  let code: SharedGame.Code
  let router: ServerRouter

  public init(
    code: SharedGame.Code,
    router: ServerRouter
  ) {
    self.code = code
    self.router = router
  }
}

public func showSharedGameMiddleware(
  _ conn: Conn<StatusLineOpen, ShowSharedGameRequest>
) -> IO<Conn<ResponseEnded, Data>> {
  conn |> redirect(
    to: conn.data.router
      .baseURL("isowords://")
      .url(for: .sharedGame(.show(conn.data.code)))
      .absoluteString
  )
}
