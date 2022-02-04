import ApplicativeRouter
import Build
import Foundation
import Parsing
import Prelude
import SharedModels
import Tagged
import _URLRouting
import XCTestDynamicOverlay

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif


private func apiRouter(
  date: @escaping () -> Date,
  decoder: JSONDecoder,
  encoder: JSONEncoder,
  secrets: [String],
  sha256: @escaping (Data) -> Data
) -> AnyParserPrinter<URLRequestData, ServerRoute.Api.Route> {
  
  let dailyChallengeRouter = OneOf {
    Route(/ServerRoute.Api.Route.DailyChallenge.start(gameMode:language:)) {
      Method.post
      Query {
        Field("gameMode", Parse(.string.rawValue(of: GameMode.self)))
        Field("language", Parse(.string.rawValue(of: Language.self)))
      }
    }
    
    Route(/ServerRoute.Api.Route.DailyChallenge.today(language:)) {
      Path { "today" }
      Query {
        Field("language", Parse(.string.rawValue(of: Language.self)))
      }
    }
    
    Route(/ServerRoute.Api.Route.DailyChallenge.results) {
      Path { "results" }
      OneOf {
        Route(/ServerRoute.Api.Route.DailyChallenge.Results.fetch(gameMode:gameNumber:language:)) {
          Query {
            OneOf {
              Field("gameMode", Parse(.string.rawValue(of: GameMode.self)))
              Field("game-mode", Parse(.string.rawValue(of: GameMode.self)))
            }
            Optionally {
              OneOf {
                Field("gameNumber", Int.parser().map(.rawValue(of: DailyChallenge.GameNumber.self)))
                Field("game-number", Int.parser().map(.rawValue(of: DailyChallenge.GameNumber.self)))
              }
            }
            Field("language", Parse(.string.rawValue(of: Language.self)))
          }
        }
        
        Route(/ServerRoute.Api.Route.DailyChallenge.Results.history(gameMode:language:)) {
          Path { "history" }
          Query {
            OneOf {
              Field("gameMode", Parse(.string.rawValue(of: GameMode.self)))
              Field("game-mode", Parse(.string.rawValue(of: GameMode.self)))
            }
            Field("language", Parse(.string.rawValue(of: Language.self)))
          }
        }
      }
    }
  }
  
  let gamesRouter = Route(/ServerRoute.Api.Route.Games.submit) {
    Method.post
    // TODO: should verifiedDataBody work with ArraySlice?
    // TODO: should URLRequest.body be Data instead of ArraySlice?
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
    Route(/ServerRoute.Api.Route.Leaderboard.fetch(gameMode:language:timeScope:)) {
      Query {
        Field("gameMode", Parse(.string.rawValue(of: GameMode.self)))
        Field("language", Parse(.string.rawValue(of: Language.self)))
        Field("timeScope", Parse(.string.rawValue(of: TimeScope.self)))
      }
    }
    
    Route(/ServerRoute.Api.Route.Leaderboard.vocab) {
      Path { "vocab" }
      OneOf {
        Route(/ServerRoute.Api.Route.Leaderboard.Vocab.fetch(language:timeScope:)) {
          Query {
            Field("language", Parse(.string.rawValue(of: Language.self)))
            Field("timeScope", Parse(.string.rawValue(of: TimeScope.self)))
          }
        }
        
        Route(/ServerRoute.Api.Route.Leaderboard.Vocab.fetchWord(wordId:)) {
          Path {
            "words"
            UUID.parser().map(.rawValue(of: Word.Id.self))
          }
        }
      }
    }
    
    Route(/ServerRoute.Api.Route.Leaderboard.weekInReview(language:)) {
      Path { "week-in-review" }
      Query {
        Field("language", Parse(.string.rawValue(of: Language.self)))
      }
    }
  }
  
  let pushRouter = OneOf {
    Route(/ServerRoute.Api.Route.Push.register) {
      Method.post
      Path { "push-tokens" }
      Body {
        Parse(.data.json(ServerRoute.Api.Route.Push.Register.self))
      }
    }
    
    Route(/ServerRoute.Api.Route.Push.updateSetting) {
      Method.post
      Path { "push-settings" }
      Body {
        Parse(.data.json(ServerRoute.Api.Route.Push.Setting.self))
      }
    }
  }
  
  let sharedGameRouter = OneOf {
    Route(/ServerRoute.Api.Route.SharedGame.fetch) {
      Path {
        Parse(.string.rawValue(of: SharedGame.Code.self))
      }
    }
    
    Route(/ServerRoute.Api.Route.SharedGame.share) {
      Method.post
      Body {
        Parse(.data.json(CompletedGame.self))
      }
    }
  }
  
  return OneOf {
    Route(/ServerRoute.Api.Route.changelog(build:)) {
      Path { "changelog" }
      Query { Field("build", Int.parser().map(.rawValue(of: Build.Number.self))) }
    }

    Route(/ServerRoute.Api.Route.config) {
      Path { "config" }
    }

    Route(/ServerRoute.Api.Route.currentPlayer) {
      Path { "current-player" }
    }

    Route(/ServerRoute.Api.Route.dailyChallenge) {
      Path { "daily-challenges" }
      dailyChallengeRouter
    }

    Route(/ServerRoute.Api.Route.games) {
      Path { "games" }
      gamesRouter
    }

    Route(/ServerRoute.Api.Route.leaderboard) {
      Path { "leaderboard-scores" }
      leaderboardRouter
    }

    Route(/ServerRoute.Api.Route.push) {
      pushRouter
    }

    Route(/ServerRoute.Api.Route.sharedGame) {
      Path {
        OneOf {
          "shared-games"
          "sharedGames"
        }
      }
      sharedGameRouter
    }

    Route(/ServerRoute.Api.Route.verifyReceipt) {
      Method.post
      Path { "verify-receipt" }
      Body { Parse(.data) }
    }
  }
  .eraseToAnyParserPrinter()
}

public func router(
  date: @escaping () -> Date,
  decoder: JSONDecoder,
  encoder: JSONEncoder,
  secrets: [String],
  sha256: @escaping (Data) -> Data
) -> AnyParserPrinter<URLRequestData, ServerRoute> {

  OneOf {
    Route(/ServerRoute.api) {
      Path { "api" }
      Parse(.destructure(ServerRoute.Api.init(accessToken:isDebug:route:))) {
        Query {
          Field("accessToken", UUID.parser().map(.rawValue(of: AccessToken.self)))
        }
        Headers {
          Field("X-Debug", Bool.parser(), default: false)
        }
        apiRouter(date: date, decoder: decoder, encoder: encoder, secrets: secrets, sha256: sha256)
      }
    }

    Route(/ServerRoute.authenticate) {
      Method.post
      Path { "api"; "authenticate" }
      verifiedDataBody(date: date, require: false, secrets: secrets, sha256: sha256)
        .map(
          .json(
            ServerRoute.AuthenticateRequest.self,
            decoder: decoder,
            encoder: encoder
          )
        )
    }

    Route(/ServerRoute.appSiteAssociation) {
      Method.get
      Path { ".well-known"; "apple-app-site-association" }
    }

    Route(/ServerRoute.appStore) {
      Method.get
      Path { "app-store" }
    }

    Route(/ServerRoute.demo .. /ServerRoute.Demo.submitGame) {
      Method.post
      Path { "demo"; "games" }
      Body { Parse(.data.json(ServerRoute.Demo.SubmitRequest.self)) }
    }

    OneOf {
      Route(/ServerRoute.download) {
        Method.get
        Path { "download" }
      }

      Route(/ServerRoute.home) {
        Method.get
      }

      Route(/ServerRoute.pressKit) {
        Method.get
        Path { "press-kit" }
      }

      Route(/ServerRoute.privacyPolicy) {
        Method.get
        Path { "privacy-policy" }
      }
    }

    Route(/ServerRoute.sharedGame .. /ServerRoute.SharedGame.show) {
      Method.get
      Path {
        OneOf { "shared-games"; "sharedGames" }
        Parse(.string.rawValue(of: SharedGame.Code.self))
      }
    }
  }
  .eraseToAnyParserPrinter()
}

#if DEBUG
  extension AnyParserPrinter where Input == URLRequestData, Output == ServerRoute {
    public static let test = router(
      date: { Date(timeIntervalSince1970: 1_234_567_890) },
      decoder: decoder,
      encoder: encoder,
      secrets: ["SECRET_DEADBEEF"],
      sha256: { $0 }
    )

    public static let failing = router(
      date: {
        XCTFail("\(Self.self).date is unimplemented")
        return .init()
      },
      decoder: decoder,
      encoder: encoder,
      secrets: ["SECRET_DEADBEEF"],
      sha256: {
        XCTFail("\(Self.self).sha256 is unimplemented")
        return $0
      }
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


extension Parser where Self: ParserPrinter {
  @inlinable
  public func eraseToAnyParserPrinter() -> AnyParserPrinter<Input, Output> {
    AnyParserPrinter(self)
  }
}
