import ApplicativeRouter
import Foundation
import Prelude
import SharedModels
import Tagged

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

private func apiRouter(
  date: @escaping () -> Date,
  decoder: JSONDecoder,
  encoder: JSONEncoder,
  secrets: [String],
  sha256: @escaping (Data) -> Data
) -> Router<ServerRoute.Api.Route> {
  let routers: [Router<ServerRoute.Api.Route>] = [
    // TODO: there appears to be a bug in the router where if the route `.config` doesn't take
    //       any arguments then it routes to "/api" instead of "/api/config".
    .case(ServerRoute.Api.Route.config(build:))
      <¢> get %> "config"
      %> queryParam("build", .int)
      <% end,

    .case(ServerRoute.Api.Route.currentPlayer)
      <¢> get %> "current-player"
      %> end,

    .case { .dailyChallenge(.start(gameMode: $0, language: $1)) }
      <¢> post %> "daily-challenges"
      %> queryParam("gameMode", .rawRepresentable)
      <%> queryParam("language", .rawRepresentable)
      <% end,

    .case { .dailyChallenge(.today(language: $0)) }
      <¢> get %> "daily-challenges" %> "today"
      %> queryParam("language", .rawRepresentable)
      <% end,

    parenthesize(
      .case { .dailyChallenge(.results(.fetch(gameMode: $0, gameNumber: $1, language: $2))) })
      <¢> get %> "daily-challenges" %> "results"
      %> (queryParam("game-mode", .rawRepresentable) <|> queryParam("gameMode", .rawRepresentable))
      <%> (queryParam("game-number", opt(.tagged(.int)))
        <|> queryParam("gameNumber", opt(.tagged(.int))))
      <%> queryParam("language", .rawRepresentable)
      <% end,

    .case { .dailyChallenge(.results(.history(gameMode: $0, language: $1))) }
      <¢> get %> "daily-challenges" %> "results" %> "history"
      %> (queryParam("game-mode", .rawRepresentable) <|> queryParam("gameMode", .rawRepresentable))
      <%> queryParam("language", .rawRepresentable)
      <% end,

    .case { .games(.submit($0)) }
      <¢> post %> "games"
      %> verifiedDataBody(date: date, secrets: secrets, sha256: sha256)
      .map(
        PartialIso.codableToJsonData(
          ServerRoute.Api.Route.Games.SubmitRequest.self, encoder: encoder, decoder: decoder
        ).inverted)
      <% end,

    parenthesize(.case { .leaderboard(.fetch(gameMode: $0, language: $1, timeScope: $2)) })
      <¢> get %> "leaderboard-scores"
      %> queryParam("gameMode", .rawRepresentable)
      <%> queryParam("language", .rawRepresentable)
      <%> queryParam("timeScope", .rawRepresentable)
      <% end,

    parenthesize(.case { .leaderboard(.vocab(.fetch(language: $0, timeScope: $1))) })
      <¢> get %> "leaderboard-scores" %> "vocab"
      %> queryParam("language", .rawRepresentable)
      <%> queryParam("timeScope", .rawRepresentable)
      <% end,

    parenthesize(.case { .leaderboard(.weekInReview(language: $0)) })
      <¢> get %> "leaderboard-scores" %> "week-in-review"
      %> queryParam("language", .rawRepresentable)
      <% end,

    .case { .leaderboard(.vocab(.fetchWord(wordId: $0))) }
      <¢> get %> "leaderboard-scores" %> "vocab" %> "words" %> pathParam(.tagged(.uuid))
      <% end,

    .case { .push(.register($0)) }
      <¢> post %> "push-tokens"
      %> jsonBody(ServerRoute.Api.Route.Push.Register.self)
      <% end,

    .case { .push(.updateSetting($0)) }
      <¢> post %> "push-settings"
      %> jsonBody(ServerRoute.Api.Route.Push.Setting.self)
      <% end,

    .case { .sharedGame(.fetch($0)) }
      <¢> get %> "sharedGames"
      %> pathParam(.tagged(.string))
      <% end,

    .case { .sharedGame(.share($0)) }
      <¢> post %> "sharedGames"
      %> jsonBody(CompletedGame.self)
      <% end,

    .case(ServerRoute.Api.Route.verifyReceipt)
      <¢> post %> "verify-receipt"
      %> dataBody
      <% end,
  ]

  return routers.reduce(.empty, <|>)
}

public func router(
  date: @escaping () -> Date,
  decoder: JSONDecoder,
  encoder: JSONEncoder,
  secrets: [String],
  sha256: @escaping (Data) -> Data
) -> Router<ServerRoute> {
  let routers: [Router<ServerRoute>] = [
    parenthesize(.tuple(ServerRoute.Api.init) >>> .case(ServerRoute.api))
      <¢> queryParam("accessToken", .tagged(.uuid))
      <%> header("X-Debug", opt(.bool, default: false))
      <%> "api"
      %> apiRouter(date: date, decoder: decoder, encoder: encoder, secrets: secrets, sha256: sha256)
      <% end,

    .case(ServerRoute.authenticate)
      <¢> post %> "api" %> "authenticate"
      %> verifiedDataBody(date: date, require: false, secrets: secrets, sha256: sha256)
      .map(
        PartialIso.codableToJsonData(
          ServerRoute.AuthenticateRequest.self, encoder: encoder, decoder: decoder
        ).inverted)
      <% end,

    .case { .appSiteAssociation }
      <¢> get %> ".well-known" %> "apple-app-site-association"
      <% end,

    .case { .appStore }
      <¢> get %> "app-store"
      <% end,

    .case { .demo(.submitGame($0)) }
      <¢> post %> "demo" %> "games"
      %> jsonBody(ServerRoute.Demo.SubmitRequest.self)
      <% end,

    .case { .download }
      <¢> get %> "download"
      <% end,

    .case { .home }
      <¢> get
      <% end,

    .case { .pressKit }
      <¢> get %> "press-kit"
      <% end,

    .case { .privacyPolicy }
      <¢> get %> "privacy-policy"
      <% end,

    .case { .sharedGame(.show($0)) }
      <¢> get %> "sharedGames"
      %> pathParam(.tagged(.string))
      <% end,
  ]

  return routers.reduce(.empty, <|>)
}

#if DEBUG
  extension Router where A == ServerRoute {
    public static let mock = router(
      date: { Date(timeIntervalSince1970: 1_234_567_890) },
      decoder: decoder,
      encoder: encoder,
      secrets: ["SECRET_DEADBEEF"],
      sha256: { $0 }
    )

    public static let unimplemented = router(
      date: { fatalError() },
      decoder: decoder,
      encoder: encoder,
      secrets: ["SECRET_DEADBEEF"],
      sha256: { _ in fatalError() }
    )
  }

  private let encoder = { () -> JSONEncoder in
    let encoder = JSONEncoder()
    encoder.outputFormatting = .sortedKeys
    encoder.dateEncodingStrategy = .secondsSince1970
    return encoder
  }()

  private let decoder = { () -> JSONDecoder in
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .secondsSince1970
    return decoder
  }()
#endif
