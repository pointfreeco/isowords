import Build
import Foundation
import Parsing
import SharedModels
import Tagged
import URLRouting
import XCTestDynamicOverlay

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

public struct ServerRouter: ParserPrinter {
  let date: () -> Date
  let decoder: JSONDecoder
  let encoder: JSONEncoder
  let secrets: [String]
  let sha256: (Data) -> Data

  public init(
    date: @escaping () -> Date,
    decoder: JSONDecoder,
    encoder: JSONEncoder,
    secrets: [String],
    sha256: @escaping (Data) -> Data
  ) {
    self.date = date
    self.decoder = decoder
    self.encoder = encoder
    self.secrets = secrets
    self.sha256 = sha256
  }

  var body: AnyParserPrinter<URLRequestData, ServerRoute> {
    OneOf {
      Route(.case(ServerRoute.api)) {
        Path { "api" }
        Parse(.memberwise(ServerRoute.Api.init(accessToken:isDebug:route:))) {
          Query {
            Field("accessToken") { UUID.parser().map(.representing(AccessToken.self)) }
          }
          Headers {
            Field("X-Debug", default: false) { Bool.parser() }
          }
          self.apiRouter
        }
      }

      Route(.case(ServerRoute.authenticate)) {
        Method.post
        Path {
          "api"
          "authenticate"
        }
        verifiedDataBody(date: date, require: false, secrets: secrets, sha256: sha256)
          .map(
            .json(
              ServerRoute.AuthenticateRequest.self,
              decoder: decoder,
              encoder: encoder
            )
          )
      }

      Route(.case(ServerRoute.appSiteAssociation)) {
        Path {
          ".well-known"
          "apple-app-site-association"
        }
      }

      Route(.case(ServerRoute.appStore)) {
        Path { "app-store" }
      }

      Route(.case(ServerRoute.demo)) {
        Method.post
        Path {
          "demo"
          "games"
        }
        Body(.json(ServerRoute.Demo.SubmitRequest.self))
          .map(.case(ServerRoute.Demo.submitGame))
      }

      OneOf {
        Route(.case(ServerRoute.download)) {
          Path { "download" }
        }

        Route(.case(ServerRoute.home))

        Route(.case(ServerRoute.pressKit)) {
          Path { "press-kit" }
        }

        Route(.case(ServerRoute.privacyPolicy)) {
          Path { "privacy-policy" }
        }
      }

      Route(.case(ServerRoute.sharedGame)) {
        Path {
          OneOf {
            "shared-games"
            "sharedGames"
          }
          Parse(.string.representing(SharedGame.Code.self))
            .map(.case(ServerRoute.SharedGame.show))
        }
      }
    }
    .eraseToAnyParserPrinter()
  }

  @ParserBuilder
  var apiRouter: AnyParserPrinter<URLRequestData, ServerRoute.Api.Route> {
    let dailyChallengeRouter = OneOf {
      Route(.case(ServerRoute.Api.Route.DailyChallenge.start(gameMode:language:))) {
        Method.post
        Query {
          Field("gameMode") { GameMode.parser() }
          Field("language") { Language.parser() }
        }
      }

      Route(.case(ServerRoute.Api.Route.DailyChallenge.today(language:))) {
        Path { "today" }
        Query {
          Field("language") { Language.parser() }
        }
      }

      Route(.case(ServerRoute.Api.Route.DailyChallenge.results)) {
        Path { "results" }
        OneOf {
          Route(
            .case(ServerRoute.Api.Route.DailyChallenge.Results.fetch(gameMode:gameNumber:language:))
          ) {
            Query {
              OneOf {
                Field("gameMode") { GameMode.parser() }
                Field("game-mode") { GameMode.parser() }
              }
              Optionally {
                OneOf {
                  Field("gameNumber") {
                    Digits().map(.representing(DailyChallenge.GameNumber.self))
                  }
                  Field("game-number") {
                    Digits().map(.representing(DailyChallenge.GameNumber.self))
                  }
                }
              }
              Field("language") { Language.parser() }
            }
          }

          Route(.case(ServerRoute.Api.Route.DailyChallenge.Results.history(gameMode:language:))) {
            Path { "history" }
            Query {
              OneOf {
                Field("gameMode") { GameMode.parser() }
                Field("game-mode") { GameMode.parser() }
              }
              Field("language") { Language.parser() }
            }
          }
        }
      }
    }

    let gamesRouter = Route(.case(ServerRoute.Api.Route.Games.submit)) {
      Method.post
      verifiedDataBody(date: date, secrets: secrets, sha256: sha256)
        .map(
          .json(
            ServerRoute.Api.Route.Games.SubmitRequest.self,
            decoder: decoder,
            encoder: encoder
          )
        )
    }

    let leaderboardRouter = OneOf {
      Route(.case(ServerRoute.Api.Route.Leaderboard.fetch(gameMode:language:timeScope:))) {
        Query {
          Field("gameMode") { GameMode.parser() }
          Field("language") { Language.parser() }
          Field("timeScope") { TimeScope.parser() }
        }
      }

      Route(.case(ServerRoute.Api.Route.Leaderboard.vocab)) {
        Path { "vocab" }
        OneOf {
          Route(.case(ServerRoute.Api.Route.Leaderboard.Vocab.fetch(language:timeScope:))) {
            Query {
              Field("language") { Language.parser() }
              Field("timeScope") { TimeScope.parser() }
            }
          }

          Route(.case(ServerRoute.Api.Route.Leaderboard.Vocab.fetchWord(wordId:))) {
            Path {
              "words"
              UUID.parser().map(.representing(Word.Id.self))
            }
          }
        }
      }

      Route(.case(ServerRoute.Api.Route.Leaderboard.weekInReview(language:))) {
        Path { "week-in-review" }
        Query {
          Field("language") { Language.parser() }
        }
      }
    }

    let pushRouter = OneOf {
      Route(.case(ServerRoute.Api.Route.Push.register)) {
        Method.post
        Path { "push-tokens" }
        Body(.json(ServerRoute.Api.Route.Push.Register.self))
      }

      Route(.case(ServerRoute.Api.Route.Push.updateSetting)) {
        Method.post
        Path { "push-settings" }
        Body(.json(ServerRoute.Api.Route.Push.Setting.self))
      }
    }

    let sharedGameRouter = OneOf {
      Route(.case(ServerRoute.Api.Route.SharedGame.fetch)) {
        Path {
          Parse(.string.representing(SharedGame.Code.self))
        }
      }

      Route(.case(ServerRoute.Api.Route.SharedGame.share)) {
        Method.post
        Body(.json(CompletedGame.self))
      }
    }

    OneOf {
      Route(.case(ServerRoute.Api.Route.changelog(build:))) {
        Path { "changelog" }
        Query {
          Field("build") { Digits().map(.representing(Build.Number.self)) }
        }
      }

      Route(.case(ServerRoute.Api.Route.config(build:))) {
        Path { "config" }
        Query {
          Field("build") { Digits().map(.representing(Build.Number.self)) }
        }
      }

      Route(.case(ServerRoute.Api.Route.currentPlayer)) {
        Path { "current-player" }
      }

      Route(.case(ServerRoute.Api.Route.dailyChallenge)) {
        Path { "daily-challenges" }
        dailyChallengeRouter
      }

      Route(.case(ServerRoute.Api.Route.games)) {
        Path { "games" }
        gamesRouter
      }

      Route(.case(ServerRoute.Api.Route.leaderboard)) {
        Path { "leaderboard-scores" }
        leaderboardRouter
      }

      Route(.case(ServerRoute.Api.Route.push)) {
        pushRouter
      }

      Route(.case(ServerRoute.Api.Route.sharedGame)) {
        Path {
          OneOf {
            "shared-games"
            "sharedGames"
          }
        }
        sharedGameRouter
      }

      Route(.case(ServerRoute.Api.Route.verifyReceipt)) {
        Method.post
        Path { "verify-receipt" }
        Body()
      }
    }
    .eraseToAnyParserPrinter()
  }

  public func parse(_ input: inout URLRequestData) throws -> ServerRoute {
    try self.body.parse(&input)
  }

  public func print(_ output: ServerRoute, into input: inout URLRequestData) throws {
    try self.body.print(output, into: &input)
  }
}

#if DEBUG
  extension ServerRouter {
    public static let test = Self(
      date: { Date(timeIntervalSince1970: 1_234_567_890) },
      decoder: jsonDecoder,
      encoder: jsonEncoder,
      secrets: ["SECRET_DEADBEEF"],
      sha256: { $0 }
    )

    public static let failing = Self(
      date: {
        XCTFail("\(Self.self).date is unimplemented")
        return .init()
      },
      decoder: jsonDecoder,
      encoder: jsonEncoder,
      secrets: ["SECRET_DEADBEEF"],
      sha256: {
        XCTFail("\(Self.self).sha256 is unimplemented")
        return $0
      }
    )
  }

  private let jsonEncoder = { () -> JSONEncoder in
    let encoder = JSONEncoder()
    encoder.outputFormatting = .sortedKeys
    encoder.dateEncodingStrategy = .secondsSince1970
    return encoder
  }()

  private let jsonDecoder = { () -> JSONDecoder in
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .secondsSince1970
    return decoder
  }()
#endif

extension Body {
  init() where Bytes == Parsers.ReplaceError<Rest<Bytes.Input>> {
    self.init { Rest<Bytes.Input>().replaceError(with: .init()) }
  }
}
