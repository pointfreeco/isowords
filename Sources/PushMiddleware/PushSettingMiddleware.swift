import DatabaseClient
import Either
import HttpPipeline
import Prelude
import ServerRoutes
import SharedModels

public struct UpdatePushSettingRequest {
  public let currentPlayer: Player
  public let database: DatabaseClient
  public let setting: ServerRoute.Api.Route.Push.Setting

  public init(
    currentPlayer: Player,
    database: DatabaseClient,
    setting: ServerRoute.Api.Route.Push.Setting
  ) {
    self.currentPlayer = currentPlayer
    self.database = database
    self.setting = setting
  }
}

public struct UpdatePushSettingResponse: Encodable {
}

public func updatePushSettingMiddleware(
  _ conn: Conn<StatusLineOpen, UpdatePushSettingRequest>
) -> IO<Conn<HeadersOpen, Either<ApiError, UpdatePushSettingResponse>>> {

  let request = conn.data

  return request.database.updatePushSetting(
    request.currentPlayer.id,
    request.setting.notificationType,
    request.setting.sendNotifications
  )
  .run
  .flatMap { errorOrSuccess in
    switch errorOrSuccess {
    case let .left(error):
      return conn.map(const(.left(ApiError(error: error))))
        |> writeStatus(.internalServerError)

    case .right():
      return conn.map(const(.right(UpdatePushSettingResponse())))
        |> writeStatus(.ok)
    }
  }
}
