import ApplicativeRouter
import Build
import Foundation
import Parsing
import Prelude
import SharedModels
import Tagged
import URLRouting
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
    Routing(/ServerRoute.Api.Route.DailyChallenge.start(gameMode:language:)) {
      Method.post
      Query {
        Field("gameMode", String.parser().pipe { GameMode.parser() })
        Field("language", String.parser().pipe { Language.parser() })
      }
    }
    
    Routing(/ServerRoute.Api.Route.DailyChallenge.today(language:)) {
      Method.get
      Path { "today" }
      Query {
        Field("language", String.parser().pipe { Language.parser() })
      }
    }
    
    Routing(/ServerRoute.Api.Route.DailyChallenge.results) {
      Path { "results" }
      OneOf {
        Routing(/ServerRoute.Api.Route.DailyChallenge.Results.fetch(gameMode:gameNumber:language:)) {
          Method.get
          Query {
            OneOf {
              Field("gameMode", String.parser().pipe { GameMode.parser() })
              Field("game-mode", String.parser().pipe { GameMode.parser() })
            }
            Optionally {
              OneOf {
                Field("gameNumber", Int.parser().pipe { DailyChallenge.GameNumber.parser() })
                Field("game-number", Int.parser().pipe { DailyChallenge.GameNumber.parser() })
              }
            }
            Field("language", String.parser().pipe { Language.parser() })
          }
        }
        
        Routing(/ServerRoute.Api.Route.DailyChallenge.Results.history(gameMode:language:)) {
          Method.get
          Path { "history" }
          Query {
            OneOf {
              Field("gameMode", String.parser().pipe { GameMode.parser() })
              Field("game-mode", String.parser().pipe { GameMode.parser() })
            }
            Field("language", String.parser().pipe { Language.parser() })
          }
        }
      }
    }
  }
  
  let gamesRouter = Routing(/ServerRoute.Api.Route.Games.submit) {
    Method.post
    // TODO: should _verifiedDataBody work with ArraySlice?
    // TODO: should JSON work with Data?
    // TODO: should URLRequest.body be Data instead of ArraySlice?
    _verifiedDataBody(date: date, secrets: secrets, sha256: sha256)
      .pipe {
        Conversion.init(
          apply: ArraySlice.init,
          unapply: { Data($0) }
        )
      }
      .pipe {
        JSON(ServerRoute.Api.Route.Games.SubmitRequest.self, decoder: decoder, encoder: encoder)
      }
  }
  
  let leaderboardRouter = OneOf {
    Routing(/ServerRoute.Api.Route.Leaderboard.fetch(gameMode:language:timeScope:)) {
      Method.get
      Query {
        Field("gameMode", String.parser().pipe { GameMode.parser() })
        Field("language", String.parser().pipe { Language.parser() })
        Field("timeScope", String.parser().pipe { TimeScope.parser() })
      }
    }
    
    Routing(/ServerRoute.Api.Route.Leaderboard.vocab) {
      Path { "vocab" }
      OneOf {
        Routing(/ServerRoute.Api.Route.Leaderboard.Vocab.fetch(language:timeScope:)) {
          Method.get
          Query {
            Field("language", String.parser().pipe { Language.parser() })
            Field("timeScope", String.parser().pipe { TimeScope.parser() })
          }
        }
        
        Routing(/ServerRoute.Api.Route.Leaderboard.Vocab.fetchWord(wordId:)) {
          Method.get
          Path {
            "words"
            UUID.parser().pipe { Word.Id.parser() }
          }
        }
      }
    }
    
    Routing(/ServerRoute.Api.Route.Leaderboard.weekInReview(language:)) {
      Method.get
      Path { "week-in-review" }
      Query {
        Field("language", String.parser().pipe { Language.parser() })
      }
    }
  }
  
  let pushRouter = OneOf {
    Routing(/ServerRoute.Api.Route.Push.register) {
      Method.post
      Path { "push-tokens" }
      Body {
        JSON(ServerRoute.Api.Route.Push.Register.self)
      }
    }
    
    Routing(/ServerRoute.Api.Route.Push.updateSetting) {
      Method.post
      Path { "push-settings" }
      Body {
        JSON(ServerRoute.Api.Route.Push.Setting.self)
      }
    }
  }
  
  let sharedGameRouter = OneOf {
    Routing(/ServerRoute.Api.Route.SharedGame.fetch) {
      Method.get
      Path {
        String.parser().pipe { SharedModels.SharedGame.Code.parser() }
      }
    }
    
    Routing(/ServerRoute.Api.Route.SharedGame.share) {
      Method.post
      Body {
        JSON(CompletedGame.self)
      }
    }
  }
  
  return OneOf {
    Routing(/ServerRoute.Api.Route.changelog(build:)) {
      Method.get
      Path { "changelog" }
      Query { Field("build", Int.parser().pipe { Build.Number.parser() }) }
    }
    
    Routing(/ServerRoute.Api.Route.config) {
      Method.get
      Path { "config" }
    }
    
    Routing(/ServerRoute.Api.Route.currentPlayer) {
      Method.get
      Path { "current-player" }
    }
    
    Routing(/ServerRoute.Api.Route.dailyChallenge) {
      Path { "daily-challenges" }
      dailyChallengeRouter
    }
    
    Routing(/ServerRoute.Api.Route.games) {
      Path { "games" }
      gamesRouter
    }
    
    Routing(/ServerRoute.Api.Route.leaderboard) {
      Path { "leaderboard-scores" }
      leaderboardRouter
    }
    
    Routing(/ServerRoute.Api.Route.push) {
      pushRouter
    }
    
    Routing(/ServerRoute.Api.Route.sharedGame) {
      Path {
        OneOf {
          "shared-games"
          "sharedGames"
        }
      }
      sharedGameRouter
    }
    
    Routing(/ServerRoute.Api.Route.verifyReceipt) {
      Method.post
      Path { "verify-receipt" }
      Body {
        Conversion(
          apply: { Data($0) },
          unapply: ArraySlice.init
        )
      }
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
    Routing(/ServerRoute.api) {
      Path { "api" }
      Parse {
        Query {
          Field("accessToken", UUID.parser().pipe { AccessToken.parser() })
        }
        Headers {
          Field("X-Debug", Bool.parser(), default: false)
        }
        apiRouter(date: date, decoder: decoder, encoder: encoder, secrets: secrets, sha256: sha256)
      }
      .pipe(UnsafeBitCast(ServerRoute.Api.init(accessToken:isDebug:route:)))
    }
    
    Routing(/ServerRoute.authenticate) {
      Method.post
      Path { "api"; "authenticate" }
      _verifiedDataBody(date: date, secrets: secrets, sha256: sha256)
        .pipe {
          Conversion.init(
            apply: ArraySlice.init,
            unapply: { Data($0) }
          )
        }
        .pipe {
          JSON(ServerRoute.AuthenticateRequest.self, decoder: decoder, encoder: encoder)
        }
    }
    
    Routing(/ServerRoute.appSiteAssociation) {
      Method.get
      Path { ".well-known"; "apple-app-site-association" }
    }
    
    Routing(/ServerRoute.appStore) {
      Method.get
      Path { "app-store" }
    }
    
    Routing(/ServerRoute.demo .. /ServerRoute.Demo.submitGame) {
      Method.post
      Path { "demo"; "games" }
      Body {
        JSON(ServerRoute.Demo.SubmitRequest.self)
      }
    }
    
    OneOf {
      Routing(/ServerRoute.download) {
        Method.get
        Path { "download" }
      }
      
      Routing(/ServerRoute.home) {
        Method.get
      }
      
      Routing(/ServerRoute.pressKit) {
        Method.get
        Path { "press-kit" }
      }
      
      Routing(/ServerRoute.privacyPolicy) {
        Method.get
        Path { "privacy-policy" }
      }
    }
    
    Routing(/ServerRoute.sharedGame .. /ServerRoute.SharedGame.show) {
      Method.get
      Path {
        OneOf { "shared-games"; "sharedGames" }
        String.parser().pipe { SharedModels.SharedGame.Code.parser() }
      }
    }
  }
  .eraseToAnyParserPrinter()
}

#if DEBUG
  extension Router where A == ServerRoute {
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
