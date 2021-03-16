import DatabaseClient
import Either
import HttpPipeline
import Prelude
import SharedModels

struct CurrentPlayerRequest {
  let database: DatabaseClient
  let player: Player
}

func currentPlayerMiddleware(
  _ conn: Conn<StatusLineOpen, CurrentPlayerRequest>
) -> IO<Conn<HeadersOpen, Either<ApiError, CurrentPlayerEnvelope>>> {

  let request = conn.data

  let currentPlayer = EitherIO(
    run: zip2(
      request.database.fetchAppleReceipt(request.player.id).run.parallel,
      request.database.fetchPlayerByAccessToken(request.player.accessToken).run.parallel
    )
    .map { appleReceipt, player -> Either<ApiError, CurrentPlayerEnvelope> in
      switch (appleReceipt, player) {
      case let (.right(appleReceipt), .right(.some(player))):
        return .right(CurrentPlayerEnvelope(appleReceipt: appleReceipt?.receipt, player: player))

      case (.right(.none), _), (_, .right(.none)), (.left, _), (_, .left):
        struct SomeError: Error {}
        return .left(ApiError(error: SomeError()))
      }
    }
    .sequential
  )

  return currentPlayer
    .run
    .flatMap { errorOrCurrentPlayer in
      switch errorOrCurrentPlayer {
      case let .left(error):
        return conn.map(const(.left(error)))
          |> writeStatus(.badRequest)

      case let .right(envelope):
        return conn.map(const(.right(envelope)))
          |> writeStatus(.ok)
      }
    }
}

private func zip2<A, B>(_ lhs: Parallel<A>, _ rhs: Parallel<B>) -> Parallel<(A, B)> {
  tuple <¢> lhs <*> rhs
}
