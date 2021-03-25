import DatabaseClient
import Either
import Foundation
#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif
import FirstPartyMocks
import HttpPipeline
import HttpPipelineTestSupport
import MailgunClient
import Overture
import ServerRoutes
import SharedModels
import SnapshotTesting
import XCTest

@testable import SiteMiddleware

class DailyChallengeMiddlewareTests: XCTestCase {
  let encoder = update(JSONEncoder()) {
    $0.dateEncodingStrategy = .secondsSince1970
    $0.outputFormatting = [.prettyPrinted, .sortedKeys]
  }

  override func setUp() {
    super.setUp()
//    SnapshotTesting.isRecording=true
  }

  func testToday_NotYetPlayed() {
    let request = URLRequest(
      url: URL(
        string:
          "/api/daily-challenges/today?accessToken=deadbeef-dead-beef-dead-beefdeadbeef&language=en"
      )!
    )

    let middleware = siteMiddleware(
      environment: update(.unimplemented) {
        $0.database.fetchPlayerByAccessToken = { _ in pure(.blob) }
        $0.database.createTodaysDailyChallenge = { request in
          pure(
            DailyChallenge(
              createdAt: Date(timeIntervalSince1970: 1_234_567_890),
              endsAt: Date(timeIntervalSince1970: 1_234_567_890),
              gameMode: request.gameMode,
              gameNumber: 1,
              id: .init(rawValue: UUID(uuidString: "deadbeef-dead-beef-dead-beefdeadbeef")!),
              language: request.language,
              puzzle: request.puzzle
            )
          )
        }
        $0.database.fetchDailyChallengeResult = { request in
          pure(DailyChallengeResult(outOf: 100, rank: nil, score: nil))
        }
        $0.randomCubes = { .mock }
      }
    )
    let result = middleware(connection(from: request)).perform()

    assertSnapshot(matching: result, as: .conn)
  }

  func testToday_Played() {
    let request = URLRequest(
      url: URL(
        string:
          "/api/daily-challenges/today?accessToken=deadbeef-dead-beef-dead-beefdeadbeef&language=en"
      )!
    )

    let middleware = siteMiddleware(
      environment: update(.unimplemented) {
        $0.database.fetchPlayerByAccessToken = { _ in pure(.blob) }
        $0.database.createTodaysDailyChallenge = { request in
          pure(
            DailyChallenge(
              createdAt: Date(timeIntervalSince1970: 1_234_567_890),
              endsAt: Date(timeIntervalSince1970: 1_234_567_890),
              gameMode: request.gameMode,
              gameNumber: 1,
              id: .init(rawValue: UUID(uuidString: "deadbeef-dead-beef-dead-beefdeadbeef")!),
              language: request.language,
              puzzle: request.puzzle
            )
          )
        }
        $0.database.fetchDailyChallengeResult = { request in
          pure(.init(outOf: 100, rank: 1, score: 10_000))
        }
        $0.randomCubes = { .mock }
      }
    )
    let result = middleware(connection(from: request)).perform()

    assertSnapshot(matching: result, as: .conn)
  }

  func testStart_Unplayed() {
    let request = update(
      URLRequest(
        url: URL(
          string:
            "/api/daily-challenges?accessToken=deadbeef-dead-beef-dead-beefdeadbeef&gameMode=unlimited&language=en"
        )!
      )
    ) { $0.httpMethod = "POST" }

    let player = Player.blob

    let middleware = siteMiddleware(
      environment: update(.unimplemented) {
        $0.database.fetchPlayerByAccessToken = { _ in pure(player) }
        $0.database.fetchTodaysDailyChallenges = { language in
          pure(
            [
              DailyChallenge(
                createdAt: Date(timeIntervalSince1970: 1_234_567_890),
                endsAt: Date(timeIntervalSince1970: 1_234_567_890),
                gameMode: .unlimited,
                gameNumber: 1,
                id: .init(rawValue: .dailyChallengeId),
                language: language,
                puzzle: .mock
              )
            ]
          )
        }
        $0.database.startDailyChallenge = { _, _ in
          pure(
            DailyChallengePlay(
              completedAt: nil,
              createdAt: .mock,
              dailyChallengeId: .init(rawValue: .dailyChallengeId),
              id: .init(rawValue: .deadbeef),
              playerId: player.id
            )
          )
        }
        $0.randomCubes = { .mock }
      }
    )
    let result = middleware(connection(from: request)).perform()

    assertSnapshot(matching: result, as: .conn)
  }

  func testSubmitScore_ValidSubmission() {
    var submittedScore: DatabaseClient.SubmitLeaderboardScore?
    var dailyChallengeRankRequest: DatabaseClient.DailyChallengeRankRequest?

    let player = Player.blob
    let puzzle = ArchivablePuzzle.mock
    let index = LatticePoint(x: .two, y: .two, z: .two)
    let move = Move(
      playedAt: Date(timeIntervalSince1970: 1_234_567_890),
      playerIndex: nil,
      reactions: nil,
      score: 1_000,
      type: .playedWord([
        .init(index: index, side: .left),
        .init(index: index, side: .right),
        .init(index: index, side: .top),
      ])
    )

    var request = URLRequest(
      url: URL(
        string: "/api/games?accessToken=deadbeef-dead-beef-dead-beefdeadbeef&timestamp=1234567890")!
    )
    request.httpMethod = "POST"
    request.httpBody = try? self.encoder.encode(
      ServerRoute.Api.Route.Games.SubmitRequest(
        gameContext: .dailyChallenge(.init(rawValue: .dailyChallengeId)),
        moves: [move]
      )
    )
    request.allHTTPHeaderFields = [
      "X-Signature": (
        request.httpBody! + Data("----SECRET_DEADBEEF----1234567890".utf8)
      )
      .base64EncodedString()
    ]

    var environment = Environment.unimplemented
    environment.database.completeDailyChallenge = {
      pure(
        DailyChallengePlay(
          completedAt: .mock,
          createdAt: .mock,
          dailyChallengeId: $0,
          id: .init(rawValue: .deadbeef),
          playerId: $1
        )
      )
    }
    environment.database.fetchPlayerByAccessToken = { _ in pure(player) }
    environment.database.fetchDailyChallengeById = { _ in
      pure(
        DailyChallenge(
          createdAt: Date(timeIntervalSince1970: 1_234_567_890),
          endsAt: Date(timeIntervalSince1970: 1_234_567_890),
          gameMode: .unlimited,
          gameNumber: 1,
          id: .init(rawValue: .dailyChallengeId),
          language: .en,
          puzzle: puzzle
        )
      )
    }
    environment.database.submitLeaderboardScore = { score in
      submittedScore = score
      return pure(
        LeaderboardScore(
          createdAt: .mock,
          dailyChallengeId: .init(rawValue: .dailyChallengeId),
          gameContext: .dailyChallenge,
          gameMode: .unlimited,
          id: .init(rawValue: .deadbeef),
          language: .en,
          moves: [move],
          playerId: player.id,
          puzzle: puzzle,
          score: 1_000
        )
      )
    }
    environment.database.fetchDailyChallengeResult = { request in
      dailyChallengeRankRequest = request
      return pure(.init(outOf: 100, rank: 1, score: 1_000))
    }
    environment.dictionary = .everyString
    environment.router = .mock

    let middleware = siteMiddleware(environment: environment)
    let result = middleware(connection(from: request)).perform()

    _assertInlineSnapshot(matching: result, as: .conn, with: """
      POST /api/games?accessToken=deadbeef-dead-beef-dead-beefdeadbeef&timestamp=1234567890
      X-Signature: ewogICJnYW1lQ29udGV4dCIgOiB7CiAgICAiZGFpbHlDaGFsbGVuZ2VJZCIgOiAiREVBREJFRUYtREVBRC1CRUVGLURFQUQtREExMTdDNEExMTMyIgogIH0sCiAgIm1vdmVzIiA6IFsKICAgIHsKICAgICAgInBsYXllZEF0IiA6IDEyMzQ1Njc4OTAsCiAgICAgICJzY29yZSIgOiAxMDAwLAogICAgICAidHlwZSIgOiB7CiAgICAgICAgInBsYXllZFdvcmQiIDogWwogICAgICAgICAgewogICAgICAgICAgICAiaW5kZXgiIDogewogICAgICAgICAgICAgICJ4IiA6IDIsCiAgICAgICAgICAgICAgInkiIDogMiwKICAgICAgICAgICAgICAieiIgOiAyCiAgICAgICAgICAgIH0sCiAgICAgICAgICAgICJzaWRlIiA6IDEKICAgICAgICAgIH0sCiAgICAgICAgICB7CiAgICAgICAgICAgICJpbmRleCIgOiB7CiAgICAgICAgICAgICAgIngiIDogMiwKICAgICAgICAgICAgICAieSIgOiAyLAogICAgICAgICAgICAgICJ6IiA6IDIKICAgICAgICAgICAgfSwKICAgICAgICAgICAgInNpZGUiIDogMgogICAgICAgICAgfSwKICAgICAgICAgIHsKICAgICAgICAgICAgImluZGV4IiA6IHsKICAgICAgICAgICAgICAieCIgOiAyLAogICAgICAgICAgICAgICJ5IiA6IDIsCiAgICAgICAgICAgICAgInoiIDogMgogICAgICAgICAgICB9LAogICAgICAgICAgICAic2lkZSIgOiAwCiAgICAgICAgICB9CiAgICAgICAgXQogICAgICB9CiAgICB9CiAgXQp9LS0tLVNFQ1JFVF9ERUFEQkVFRi0tLS0xMjM0NTY3ODkw
      
      {
        "gameContext" : {
          "dailyChallengeId" : "DEADBEEF-DEAD-BEEF-DEAD-DA117C4A1132"
        },
        "moves" : [
          {
            "playedAt" : 1234567890,
            "score" : 1000,
            "type" : {
              "playedWord" : [
                {
                  "index" : {
                    "x" : 2,
                    "y" : 2,
                    "z" : 2
                  },
                  "side" : 1
                },
                {
                  "index" : {
                    "x" : 2,
                    "y" : 2,
                    "z" : 2
                  },
                  "side" : 2
                },
                {
                  "index" : {
                    "x" : 2,
                    "y" : 2,
                    "z" : 2
                  },
                  "side" : 0
                }
              ]
            }
          }
        ]
      }
      
      200 OK
      Content-Length: 107
      Content-Type: application/json
      Referrer-Policy: strict-origin-when-cross-origin
      X-Content-Type-Options: nosniff
      X-Download-Options: noopen
      X-Frame-Options: SAMEORIGIN
      X-Permitted-Cross-Domain-Policies: none
      X-XSS-Protection: 1; mode=block
      
      {
        "dailyChallenge" : {
          "outOf" : 100,
          "rank" : 1,
          "score" : 1000,
          "started" : false
        }
      }
      """
    )

    XCTAssertEqual(
      submittedScore,
      DatabaseClient.SubmitLeaderboardScore(
        dailyChallengeId: .init(rawValue: .dailyChallengeId),
        gameContext: .dailyChallenge,
        gameMode: .unlimited,
        language: .en,
        moves: [move],
        playerId: player.id,
        puzzle: puzzle,
        score: 1_000,
        words: [.init(moveIndex: 0, score: 1_000, word: "ABC")]
      )
    )
    XCTAssertEqual(
      dailyChallengeRankRequest,
      .init(
        dailyChallengeId: .init(rawValue: .dailyChallengeId),
        playerId: player.id
      )
    )
  }

  func testSubmitScore_InvalidSubmission() {
    var request = URLRequest(
      url: URL(
        string: "/api/games?accessToken=deadbeef-dead-beef-dead-beefdeadbeef&timestamp=1234567890")!
    )
    request.httpMethod = "POST"
    request.httpBody = try? self.encoder.encode(
      ServerRoute.Api.Route.Games.SubmitRequest(
        gameContext: .dailyChallenge(
          .init(rawValue: .dailyChallengeId)
        ),
        moves: [
          .init(
            playedAt: Date(timeIntervalSince1970: 1_234_567_890),
            playerIndex: nil,
            reactions: nil,
            score: 1_000,
            type: .playedWord([
              .init(index: LatticePoint.zero, side: .left),
              .init(index: LatticePoint.zero, side: .right),
              .init(index: LatticePoint(x: 1, y: 0, z: 0)!, side: .right),  // impossible move
            ])
          )
        ]
      )
    )
    request.allHTTPHeaderFields = [
      "X-Signature": (
         request.httpBody! + Data("----SECRET_DEADBEEF----1234567890".utf8)
       )
       .base64EncodedString()
    ]

    var environment = Environment.unimplemented
    environment.database.fetchPlayerByAccessToken = { _ in pure(.blob) }
    environment.database.fetchDailyChallengeById = { _ in
      pure(
        DailyChallenge(
          createdAt: Date(timeIntervalSince1970: 1_234_567_890),
          endsAt: Date(timeIntervalSince1970: 1_234_567_890),
          gameMode: .unlimited,
          gameNumber: 1,
          id: .init(rawValue: .dailyChallengeId),
          language: .en,
          puzzle: .mock
        )
      )
    }
    environment.mailgun.sendEmail = MailgunClient.noop.sendEmail
    environment.router = .mock

    let middleware = siteMiddleware(environment: environment)
    let result = middleware(connection(from: request)).perform()

    // NB: Linux's localized message is different
    #if !os(Linux)
      _assertInlineSnapshot(matching: result, as: .conn, with: #"""
        POST /api/games?accessToken=deadbeef-dead-beef-dead-beefdeadbeef&timestamp=1234567890
        X-Signature: ewogICJnYW1lQ29udGV4dCIgOiB7CiAgICAiZGFpbHlDaGFsbGVuZ2VJZCIgOiAiREVBREJFRUYtREVBRC1CRUVGLURFQUQtREExMTdDNEExMTMyIgogIH0sCiAgIm1vdmVzIiA6IFsKICAgIHsKICAgICAgInBsYXllZEF0IiA6IDEyMzQ1Njc4OTAsCiAgICAgICJzY29yZSIgOiAxMDAwLAogICAgICAidHlwZSIgOiB7CiAgICAgICAgInBsYXllZFdvcmQiIDogWwogICAgICAgICAgewogICAgICAgICAgICAiaW5kZXgiIDogewogICAgICAgICAgICAgICJ4IiA6IDAsCiAgICAgICAgICAgICAgInkiIDogMCwKICAgICAgICAgICAgICAieiIgOiAwCiAgICAgICAgICAgIH0sCiAgICAgICAgICAgICJzaWRlIiA6IDEKICAgICAgICAgIH0sCiAgICAgICAgICB7CiAgICAgICAgICAgICJpbmRleCIgOiB7CiAgICAgICAgICAgICAgIngiIDogMCwKICAgICAgICAgICAgICAieSIgOiAwLAogICAgICAgICAgICAgICJ6IiA6IDAKICAgICAgICAgICAgfSwKICAgICAgICAgICAgInNpZGUiIDogMgogICAgICAgICAgfSwKICAgICAgICAgIHsKICAgICAgICAgICAgImluZGV4IiA6IHsKICAgICAgICAgICAgICAieCIgOiAxLAogICAgICAgICAgICAgICJ5IiA6IDAsCiAgICAgICAgICAgICAgInoiIDogMAogICAgICAgICAgICB9LAogICAgICAgICAgICAic2lkZSIgOiAyCiAgICAgICAgICB9CiAgICAgICAgXQogICAgICB9CiAgICB9CiAgXQp9LS0tLVNFQ1JFVF9ERUFEQkVFRi0tLS0xMjM0NTY3ODkw

        {
          "gameContext" : {
            "dailyChallengeId" : "DEADBEEF-DEAD-BEEF-DEAD-DA117C4A1132"
          },
          "moves" : [
            {
              "playedAt" : 1234567890,
              "score" : 1000,
              "type" : {
                "playedWord" : [
                  {
                    "index" : {
                      "x" : 0,
                      "y" : 0,
                      "z" : 0
                    },
                    "side" : 1
                  },
                  {
                    "index" : {
                      "x" : 0,
                      "y" : 0,
                      "z" : 0
                    },
                    "side" : 2
                  },
                  {
                    "index" : {
                      "x" : 1,
                      "y" : 0,
                      "z" : 0
                    },
                    "side" : 2
                  }
                ]
              }
            }
          ]
        }

        400 Bad Request
        Content-Length: 492
        Content-Type: application/json
        Referrer-Policy: strict-origin-when-cross-origin
        X-Content-Type-Options: nosniff
        X-Download-Options: noopen
        X-Frame-Options: SAMEORIGIN
        X-Permitted-Cross-Domain-Policies: none
        X-XSS-Protection: 1; mode=block

        {
          "errorDump" : "▿ SharedModels.ApiError\n  - errorDump: \"- LeaderboardMiddleware.VerificationFailed\\n\"\n  - file: \"LeaderboardMiddleware\/SubmitGameMiddleware.swift\"\n  - line: 110\n  - message: \"The operation couldn’t be completed. (LeaderboardMiddleware.VerificationFailed error 1.)\"\n",
          "file" : "LeaderboardMiddleware\/SubmitGameMiddleware.swift",
          "line" : 203,
          "message" : "The operation couldn’t be completed. (LeaderboardMiddleware.VerificationFailed error 1.)"
        }
        """#
      )
    #endif
  }

  func testFetchDailyChallengeResults() {
    let request = URLRequest(
      url: URL(
        string: """
          /api/daily-challenges/results?accessToken=deadbeef-dead-beef-dead-beefdeadbeef&\
          gameMode=unlimited&\
          language=en
          """
      )!
    )

    var environment = Environment.unimplemented
    environment.database.fetchPlayerByAccessToken = { _ in pure(.blob) }
    environment.database.fetchDailyChallengeResults = { request in
      pure(
        [
          FetchDailyChallengeResultsResponse.Result(
            isSupporter: false,
            isYourScore: true,
            outOf: 42,
            playerDisplayName: "Blob",
            playerId: .init(rawValue: .deadbeef),
            rank: 1,
            score: 1_000
          ),
          FetchDailyChallengeResultsResponse.Result(
            isSupporter: false,
            isYourScore: true,
            outOf: 100,
            playerDisplayName: "Blob",
            playerId: .init(rawValue: .deadbeef),
            rank: 3,
            score: 2_000
          ),
        ]
      )
    }

    let middleware = siteMiddleware(environment: environment)
    let result = middleware(connection(from: request)).perform()

    _assertInlineSnapshot(matching: result, as: .conn, with: """
      GET /api/daily-challenges/results?accessToken=deadbeef-dead-beef-dead-beefdeadbeef&gameMode=unlimited&language=en
      
      200 OK
      Content-Length: 471
      Content-Type: application/json
      Referrer-Policy: strict-origin-when-cross-origin
      X-Content-Type-Options: nosniff
      X-Download-Options: noopen
      X-Frame-Options: SAMEORIGIN
      X-Permitted-Cross-Domain-Policies: none
      X-XSS-Protection: 1; mode=block
      
      {
        "results" : [
          {
            "isSupporter" : false,
            "isYourScore" : true,
            "outOf" : 42,
            "playerDisplayName" : "Blob",
            "playerId" : "DEADBEEF-DEAD-BEEF-DEAD-BEEFDEADBEEF",
            "rank" : 1,
            "score" : 1000
          },
          {
            "isSupporter" : false,
            "isYourScore" : true,
            "outOf" : 100,
            "playerDisplayName" : "Blob",
            "playerId" : "DEADBEEF-DEAD-BEEF-DEAD-BEEFDEADBEEF",
            "rank" : 3,
            "score" : 2000
          }
        ]
      }
      """
    )
  }
}
