import Build
import CasePaths
import Foundation
import Parsing
import SharedModels
import Tagged
import URLRouting
import IssueReporting

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

  public var body: some Router<ServerRoute> {
    OneOf {
      Route(.case(\ServerRoute.AllCasePaths.api)) {
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

      Route(.case(\ServerRoute.AllCasePaths.authenticate)) {
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

      Route(.case(\ServerRoute.AllCasePaths.appSiteAssociation)) {
        Path {
          ".well-known"
          "apple-app-site-association"
        }
      }

      Route(.case(\ServerRoute.AllCasePaths.appStore)) {
        Path { "app-store" }
      }

      Route(.case(\ServerRoute.AllCasePaths.demo)) {
        Method.post
        Path {
          "demo"
          "games"
        }
        Body(.json(ServerRoute.Demo.SubmitRequest.self))
          .map(.case(\ServerRoute.Demo.AllCasePaths.submitGame))
      }

      OneOf {
        Route(.case(\ServerRoute.AllCasePaths.download)) {
          Path { "download" }
        }

        Route(.case(\ServerRoute.AllCasePaths.home))

        Route(.case(\ServerRoute.AllCasePaths.pressKit)) {
          Path { "press-kit" }
        }

        Route(.case(\ServerRoute.AllCasePaths.privacyPolicy)) {
          Path { "privacy-policy" }
        }
      }

      Route(.case(\ServerRoute.AllCasePaths.sharedGame)) {
        Path {
          OneOf {
            "shared-games"
            "sharedGames"
          }
          Parse(.string.representing(SharedGame.Code.self))
            .map(.case(\ServerRoute.SharedGame.AllCasePaths.show))
        }
      }
    }
    .eraseToAnyParserPrinter()
  }

  @ParserBuilder<URLRequestData>
  var apiRouter: AnyParserPrinter<URLRequestData, ServerRoute.Api.Route> {
    let dailyChallengeRouter = OneOf {
      Route(.case(\ServerRoute.Api.Route.DailyChallenge.AllCasePaths.start, as: (GameMode, Language).self)) {
        Method.post
        Query {
          Field("gameMode") { GameMode.parser() }
          Field("language") { Language.parser() }
        }
      }

      Route(.case(\ServerRoute.Api.Route.DailyChallenge.AllCasePaths.today)) {
        Path { "today" }
        Query {
          Field("language") { Language.parser() }
        }
      }

      Route(.case(\ServerRoute.Api.Route.DailyChallenge.AllCasePaths.results)) {
        Path { "results" }
        OneOf {
          Route(
            .case(\ServerRoute.Api.Route.DailyChallenge.Results.AllCasePaths.fetch,
              as: (GameMode, SharedModels.DailyChallenge.GameNumber?, Language).self)
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

          Route(.case(\ServerRoute.Api.Route.DailyChallenge.Results.AllCasePaths.history, as: (GameMode, Language).self)) {
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

    let gamesRouter = Route(.case(\ServerRoute.Api.Route.Games.AllCasePaths.submit)) {
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
      Route(.case(\ServerRoute.Api.Route.Leaderboard.AllCasePaths.fetch,
          as: (GameMode, Language, TimeScope).self)) {
        Query {
          Field("gameMode") { GameMode.parser() }
          Field("language") { Language.parser() }
          Field("timeScope") { TimeScope.parser() }
        }
      }

      Route(.case(\ServerRoute.Api.Route.Leaderboard.AllCasePaths.vocab)) {
        Path { "vocab" }
        OneOf {
          Route(.case(\ServerRoute.Api.Route.Leaderboard.Vocab.AllCasePaths.fetch, as: (Language, TimeScope).self)) {
            Query {
              Field("language") { Language.parser() }
              Field("timeScope") { TimeScope.parser() }
            }
          }

          Route(.case(\ServerRoute.Api.Route.Leaderboard.Vocab.AllCasePaths.fetchWord)) {
            Path {
              "words"
              UUID.parser().map(.representing(Word.Id.self))
            }
          }
        }
      }

      Route(.case(\ServerRoute.Api.Route.Leaderboard.AllCasePaths.weekInReview)) {
        Path { "week-in-review" }
        Query {
          Field("language") { Language.parser() }
        }
      }
    }

    let pushRouter = OneOf {
      Route(.case(\ServerRoute.Api.Route.Push.AllCasePaths.register)) {
        Method.post
        Path { "push-tokens" }
        Body(.json(ServerRoute.Api.Route.Push.Register.self))
      }

      Route(.case(\ServerRoute.Api.Route.Push.AllCasePaths.updateSetting)) {
        Method.post
        Path { "push-settings" }
        Body(.json(ServerRoute.Api.Route.Push.Setting.self))
      }
    }

    let sharedGameRouter = OneOf {
      Route(.case(\ServerRoute.Api.Route.SharedGame.AllCasePaths.fetch)) {
        Path {
          Parse(.string.representing(SharedGame.Code.self))
        }
      }

      Route(.case(\ServerRoute.Api.Route.SharedGame.AllCasePaths.share)) {
        Method.post
        Body(.json(CompletedGame.self))
      }
    }

    OneOf {
      Route(.case(\ServerRoute.Api.Route.AllCasePaths.changelog)) {
        Path { "changelog" }
        Query {
          Field("build") { Digits().map(.representing(Build.Number.self)) }
        }
      }

      Route(.case(\ServerRoute.Api.Route.AllCasePaths.config)) {
        Path { "config" }
        Query {
          Field("build") { Digits().map(.representing(Build.Number.self)) }
        }
      }

      Route(.case(\ServerRoute.Api.Route.AllCasePaths.currentPlayer)) {
        Path { "current-player" }
      }

      Route(.case(\ServerRoute.Api.Route.AllCasePaths.dailyChallenge)) {
        Path { "daily-challenges" }
        dailyChallengeRouter
      }

      Route(.case(\ServerRoute.Api.Route.AllCasePaths.games)) {
        Path { "games" }
        gamesRouter
      }

      Route(.case(\ServerRoute.Api.Route.AllCasePaths.leaderboard)) {
        Path { "leaderboard-scores" }
        leaderboardRouter
      }

      Route(.case(\ServerRoute.Api.Route.AllCasePaths.push)) {
        pushRouter
      }

      Route(.case(\ServerRoute.Api.Route.AllCasePaths.sharedGame)) {
        Path {
          OneOf {
            "shared-games"
            "sharedGames"
          }
        }
        sharedGameRouter
      }

      Route(.case(\ServerRoute.Api.Route.AllCasePaths.verifyReceipt)) {
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

    public static let testValue = Self(
      date: unimplemented("\(Self.self).date", placeholder: Date()),
      decoder: jsonDecoder,
      encoder: jsonEncoder,
      secrets: ["SECRET_DEADBEEF"],
      sha256: {
        reportIssue("Unimplemented: \(Self.self).sha256")
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

extension Conversion {
  fileprivate static func `case`<Enum: CasePathable, Path: CasePath, Values>(
    _ keyPath: KeyPath<Enum.AllCasePaths, Path>,
    as _: Values.Type
  ) -> Self where Self == AnyCasePath<Enum, Values>, Path.Root == Enum {
    let path = Enum.allCasePaths[keyPath: keyPath]
    return AnyCasePath(
      embed: { path.embed($0 as! Path.Value) },
      extract: { path.extract(from: $0).map { $0 as! Values } }
    )
  }
}
