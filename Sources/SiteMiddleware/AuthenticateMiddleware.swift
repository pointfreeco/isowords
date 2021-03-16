import DatabaseClient
import Either
import EnvVars
import Foundation
import HttpPipeline
import MiddlewareHelpers
import Prelude
import ServerRouter
import SharedModels

struct AuthenticateRequest {
  public let database: DatabaseClient
  public let deviceId: DeviceId
  public let displayName: String?
  public var gameCenterLocalPlayerId: GameCenterLocalPlayerId?
  public var timeZone: String
}

func authenticateMiddleware(
  _ conn: Conn<StatusLineOpen, AuthenticateRequest>
) -> IO<Conn<HeadersOpen, Either<ApiError, CurrentPlayerEnvelope>>> {

  var request = conn.data
  if request.gameCenterLocalPlayerId == "Unavailable Player Identification" {
    request.gameCenterLocalPlayerId = nil
  }

  let insertPlayer = request.database.insertPlayer(
    .init(
      deviceId: request.deviceId,
      displayName: request.displayName,
      gameCenterLocalPlayerId: request.gameCenterLocalPlayerId,
      timeZone: request.timeZone
    )
  )
  let deviceIdPlayer = request.database.fetchPlayerByDeviceId(request.deviceId)
  let updatePlayerWithId = {
    request.database.updatePlayer(
      .init(
        displayName: request.displayName,
        gameCenterLocalPlayerId: request.gameCenterLocalPlayerId,
        playerId: $0,
        timeZone: request.timeZone
      )
    )
  }

  let player: EitherIO<Error, Player>
  if let gameCenterLocalPlayerId = request.gameCenterLocalPlayerId {
    player = request.database.fetchPlayerByGameCenterLocalPlayerId(gameCenterLocalPlayerId)
      .flatMap { player -> EitherIO<Error, Player> in
        guard let player = player else {
          return request.database.fetchPlayerByDeviceId(request.deviceId)
            .flatMap { player in
              guard let player = player else { return insertPlayer }
              return updatePlayerWithId(player.id)
            }
        }
        return updatePlayerWithId(player.id)
      }
  } else {
    player =
      deviceIdPlayer
      .flatMap { player in
        guard let player = player else { return insertPlayer }
        return pure(player)
      }
  }

  let envelope = player.flatMap { player in
    request.database.fetchAppleReceipt(player.id)
      .map { CurrentPlayerEnvelope(appleReceipt: $0?.receipt, player: player) }
  }

  return envelope
    .run
    .flatMap { errorOrPlayer in
      switch errorOrPlayer {
      case let .left(error):
        return conn.map(const(.left(ApiError(error: error))))
          |> writeStatus(.badRequest)
      case let .right(envelope):
        return conn.map(const(.right(envelope)))
          |> writeStatus(.ok)
      }
    }
}
