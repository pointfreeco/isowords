import DatabaseClient
import Either
import EnvVars
import Foundation
import HttpPipeline
import MiddlewareHelpers
import Prelude
import ServerRouter
import SharedModels

public struct VerifyReceiptRequest {
  public let database: DatabaseClient
  public let itunes: ItunesClient
  public let receiptData: Data
  public let currentPlayer: Player

  public init(
    database: DatabaseClient,
    itunes: ItunesClient,
    receiptData: Data,
    currentPlayer: Player
  ) {
    self.database = database
    self.itunes = itunes
    self.receiptData = receiptData
    self.currentPlayer = currentPlayer
  }
}

public func verifyReceiptMiddleware(
  _ conn: Conn<StatusLineOpen, VerifyReceiptRequest>
) -> IO<Conn<HeadersOpen, Either<ApiError, VerifyReceiptEnvelope>>> {

  let request = conn.data

  let verifyResponse1 =
    // First try verifying on production
    request.itunes.verify(request.receiptData, .production)
    // If that fails, try sandbox
    .catch { _ in request.itunes.verify(request.receiptData, .sandbox) }
    // If any of that succeeds with a non-zero status code, retry on sandbox
    .flatMap { response, data in
      response.status == 0
        ? pure((response, data))
        : request.itunes.verify(request.receiptData, .sandbox)
    }
  let verifyResponse2 =
    verifyResponse1
    // If any of that succeeds with a non-zero status code, then fail.
    .flatMap { response, data in
      response.status == 0
        ? pure((response, data))
        : throwE(URLError(.badServerResponse))
    }
    .flatMap { response, data -> EitherIO<Error, AppleVerifyReceiptResponse> in
      do {
        return request.database.updateAppleReceipt(
          request.currentPlayer.id,
          try jsonDecoder.decode(AppleVerifyReceiptResponse.self, from: data)
        )
        .map { _ in response }
      } catch {
        return throwE(ApiError(error: error))
      }
    }

  return verifyResponse2
    .run
    .flatMap { errorOrResponse in
      switch errorOrResponse {
      case let .left(error):
        return conn.map(const(.left(ApiError(error: error))))
          |> writeStatus(.badRequest)

      case let .right(response):
        return conn.map(
          const(
            .right(
              VerifyReceiptEnvelope(
                verifiedProductIds: response.receipt.inApp.map { $0.productId }
              )
            )
          )
        )
          |> writeStatus(.ok)
      }
    }
}

private let jsonDecoder = JSONDecoder()
