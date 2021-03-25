import ApplicativeRouter
import DailyChallengeMiddleware
import DatabaseClient
import DictionaryClient
import Either
import EnvVars
import Foundation
import HttpPipeline
import LeaderboardMiddleware
import MailgunClient
import MiddlewareHelpers
import Overture
import Prelude
import PushMiddleware
import ServerConfigMiddleware
import ServerRouter
import ServerRoutes
import ShareGameMiddleware
import SharedModels
import SnsClient
import VerifyReceiptMiddleware

let apiMiddleware: Middleware<StatusLineOpen, ResponseEnded, RequireCurrentPlayerInput, Data> =
  requireCurrentPlayer
  <<< errorReporting
  <| _apiMiddleware

struct RequireCurrentPlayerInput {
  var api: ServerRoute.Api
  var database: DatabaseClient
  var dictionary: DictionaryClient
  var envVars: EnvVars
  var isDebug: Bool
  var itunes: ItunesClient
  var mailgun: MailgunClient
  var randomCubes: () -> ArchivablePuzzle
  var router: Router<ServerRoute>
  var snsClient: SnsClient
}

struct RequireCurrentPlayerOutput {
  var database: DatabaseClient
  var dictionary: DictionaryClient
  var envVars: EnvVars
  var isDebug: Bool
  var itunes: ItunesClient
  var mailgun: MailgunClient
  var player: Player
  var randomCubes: () -> ArchivablePuzzle
  var route: ServerRoute.Api.Route
  var router: Router<ServerRoute>
  var snsClient: SnsClient
}

func requireCurrentPlayer(
  _ middleware: @escaping Middleware<
    StatusLineOpen, ResponseEnded, RequireCurrentPlayerOutput, Data
  >
) -> Middleware<StatusLineOpen, ResponseEnded, RequireCurrentPlayerInput, Data> {
  { (conn: Conn<StatusLineOpen, RequireCurrentPlayerInput>) in

    return conn.data.database.fetchPlayerByAccessToken(conn.data.api.accessToken)
      .run
      .flatMap { errorOrPlayer in
        switch errorOrPlayer {
        case let .left(error):
          return conn.map(const(ApiError(error: error)))
            |> writeStatus(.unauthorized)
            >=> respondJson(envVars: conn.data.envVars)

        case .right(.none):
          struct UserNotFound: Error {}
          return conn.map(const(ApiError(error: UserNotFound())))
            |> writeStatus(.unauthorized)
            >=> respondJson(envVars: conn.data.envVars)

        case let .right(.some(player)):
          return conn.map(
            const(
              .init(
                database: conn.data.database,
                dictionary: conn.data.dictionary,
                envVars: conn.data.envVars,
                isDebug: conn.data.isDebug,
                itunes: conn.data.itunes,
                mailgun: conn.data.mailgun,
                player: player,
                randomCubes: conn.data.randomCubes,
                route: conn.data.api.route,
                router: conn.data.router,
                snsClient: conn.data.snsClient
              )
            )
          )
            |> middleware
        }
      }
  }
}

private func _apiMiddleware(
  _ conn: Conn<StatusLineOpen, RequireCurrentPlayerOutput>
) -> IO<Conn<ResponseEnded, Data>> {

  switch conn.data.route {
  case .config:
    return conn.map(const(()))
      |> serverConfig
      >=> respondJson(envVars: conn.data.envVars)

  case .currentPlayer:
    return conn.map(
      const(
        .init(
          database: conn.data.database,
          player: conn.data.player
        )
      )
    )
      |> currentPlayerMiddleware
      >=> respondJson(envVars: conn.data.envVars)

  case let .dailyChallenge(.results(.fetch(gameMode, gameNumber, language))):
    return conn.map(
      const(
        FetchDailyChallengeResultsRequest(
          currentPlayer: conn.data.player,
          database: conn.data.database,
          gameMode: gameMode,
          gameNumber: gameNumber,
          language: language
        )
      )
    )
      |> fetchDailyChallengeResults
      >=> respondJson(envVars: conn.data.envVars)

  case let .dailyChallenge(.results(.history(gameMode, language))):
    return conn.map(
      const(
        DailyChallengeHistoryRequest(
          currentPlayer: conn.data.player,
          database: conn.data.database,
          gameMode: gameMode,
          language: language
        )
      )
    )
      |> fetchRecentDailyChallenges
      >=> respondJson(envVars: conn.data.envVars)

  case let .dailyChallenge(.start(gameMode, language)):
    return conn.map(
      const(
        StartDailyChallengeRequest(
          currentPlayer: conn.data.player,
          database: conn.data.database,
          gameMode: gameMode,
          language: language
        )
      )
    )
      |> startDailyChallengeMiddleware
      >=> respondJson(envVars: conn.data.envVars)

  case let .dailyChallenge(.today(language: language)):
    return conn.map(
      const(
        .init(
          currentPlayer: conn.data.player,
          database: conn.data.database,
          language: language,
          randomCubes: conn.data.randomCubes
        )
      )
    )
      |> fetchTodaysDailyChallengeMiddleware
      >=> respondJson(envVars: conn.data.envVars)

  case let .games(.submit(request)):
    return conn.map(
      const(
        .init(
          currentPlayer: conn.data.player,
          database: conn.data.database,
          dictionary: conn.data.dictionary,
          submitRequest: request
        )
      )
    )
      |> submitGameMiddleware
      >=> respondJson(envVars: conn.data.envVars)

  case let .leaderboard(.fetch(gameMode: gameMode, language: language, timeScope: timeScope)):
    return
      conn
      .map(
        const(
          .init(
            currentPlayer: conn.data.player,
            database: conn.data.database,
            gameMode: gameMode,
            language: language,
            timeScope: timeScope
          )
        )
      )
      |> fetchLeaderboardMiddleware
      >=> respondJson(envVars: conn.data.envVars)

  case let .leaderboard(.vocab(.fetch(language: language, timeScope: timeScope))):
    return conn.map(
      const(
        .init(
          currentPlayer: conn.data.player,
          database: conn.data.database,
          language: language,
          timeScope: timeScope
        )
      )
    )
      |> fetchVocabLeaderboard
      >=> respondJson(envVars: conn.data.envVars)

  case let .leaderboard(.vocab(.fetchWord(wordId: wordId))):
    return conn.map(
      const(
        FetchVocabWordRequest(
          database: conn.data.database,
          wordId: wordId
        )
      )
    )
      |> fetchVocabWord
      >=> respondJson(envVars: conn.data.envVars)

  case let .leaderboard(.weekInReview(language: language)):
    return conn.map(
      const(
        FetchWeekInReviewRequest(
          currentPlayer: conn.data.player,
          database: conn.data.database,
          language: language
        )
      )
    )
      |> fetchWeekInReview
      >=> respondJson(envVars: conn.data.envVars)

  case let .push(.register(register)):
    return conn.map(
      const(
        .init(
          authorizationStatus: register.authorizationStatus,
          awsPlatformApplicationArn: conn.data.isDebug
            ? conn.data.envVars.awsPlatformApplicationSandboxArn
            : conn.data.envVars.awsPlatformApplicationArn,
          build: register.build,
          currentPlayer: conn.data.player,
          database: conn.data.database,
          snsClient: conn.data.snsClient,
          token: register.token
        )
      )
    )
      |> registerPushTokenMiddleware
      >=> respondJson(envVars: conn.data.envVars)

  case let .push(.updateSetting(setting)):
    return conn.map(
      const(
        .init(
          currentPlayer: conn.data.player,
          database: conn.data.database,
          setting: setting
        )
      )
    )
      |> updatePushSettingMiddleware
      >=> respondJson(envVars: conn.data.envVars)

  case let .sharedGame(.fetch(code)):
    return conn.map(const(.init(code: code, database: conn.data.database)))
      |> fetchSharedGameMiddleware
      >=> respondJson(envVars: conn.data.envVars)

  case let .sharedGame(.share(completedGame)):
    return conn.map(
      const(
        ShareGameRequest(
          completedGame: completedGame,
          currentPlayer: conn.data.player,
          database: conn.data.database,
          envVars: conn.data.envVars,
          router: conn.data.router
        )
      )
    )
      |> submitSharedGameMiddleware
      >=> respondJson(envVars: conn.data.envVars)

  case let .verifyReceipt(receiptData):
    return conn.map(
      const(
        .init(
          database: conn.data.database,
          itunes: conn.data.itunes,
          receiptData: receiptData,
          currentPlayer: conn.data.player
        )
      )
    )
      |> verifyReceiptMiddleware
      >=> respondJson(envVars: conn.data.envVars)
  }
}
