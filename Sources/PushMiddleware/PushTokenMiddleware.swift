import DatabaseClient
import Either
import HttpPipeline
import Prelude
import SharedModels
import SnsClient

public struct RegisterPushTokenRequest {
  public let authorizationStatus: PushAuthorizationStatus
  public let awsPlatformApplicationArn: PlatformArn
  public let build: Int
  public let currentPlayer: Player
  public let database: DatabaseClient
  public let snsClient: SnsClient
  public let token: String

  public init(
    authorizationStatus: PushAuthorizationStatus,
    awsPlatformApplicationArn: PlatformArn,
    build: Int,
    currentPlayer: Player,
    database: DatabaseClient,
    snsClient: SnsClient,
    token: String
  ) {
    self.authorizationStatus = authorizationStatus
    self.awsPlatformApplicationArn = awsPlatformApplicationArn
    self.build = build
    self.currentPlayer = currentPlayer
    self.database = database
    self.snsClient = snsClient
    self.token = token
  }
}

public struct RegisterPushTokenResponse: Encodable {
}

public func registerPushTokenMiddleware(
  _ conn: Conn<StatusLineOpen, RegisterPushTokenRequest>
) -> IO<Conn<HeadersOpen, Either<ApiError, RegisterPushTokenResponse>>> {

  let request = conn.data

  return request.snsClient
    .createPlatformEndpoint(
      .init(
        apnsToken: request.token,
        platformApplicationArn: request.awsPlatformApplicationArn
      )
    )
    .flatMap { response in
      request.database.insertPushToken(
        .init(
          arn: response.response.result.endpointArn,
          authorizationStatus: request.authorizationStatus,
          build: request.build,
          player: request.currentPlayer,
          token: request.token
        )
      )
    }
    .run
    .flatMap { errorOrSuccess in
      switch errorOrSuccess {
      case let .left(error):
        return conn.map(const(.left(ApiError(error: error))))
          |> writeStatus(.badRequest)

      case .right():
        return conn.map(const(.right(RegisterPushTokenResponse())))
          |> writeStatus(.ok)
      }
    }
}
