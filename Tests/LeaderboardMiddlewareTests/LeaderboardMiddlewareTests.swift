import CustomDump
import DatabaseClient
import Either
import EnvVars
import Foundation
import HttpPipeline
import HttpPipelineTestSupport
import InlineSnapshotTesting
import Overture
import Prelude
import ServerRouter
import SharedModels
import XCTest

@testable import SiteMiddleware

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

class LeaderboardMiddlewareTests: XCTestCase {
  func testSubmitLeaderboardScore() {
    let player = Player.blob
    let puzzle = ArchivablePuzzle.mock
    let index = LatticePoint(x: .two, y: .two, z: .two)
    let moves: Moves = [
      Move(
        // NB: Fractional second forces same encoding on Linux (Apple platforms omit trailing '.0')
        playedAt: Date(timeIntervalSince1970: 1_234_567_890.5),
        playerIndex: nil,
        reactions: nil,
        score: 27,
        type: .playedWord([
          .init(index: index, side: .top),
          .init(index: index, side: .left),
          .init(index: index, side: .right),
        ])
      )
    ]
    var request = URLRequest(
      url: URL(
        string: "/api/games?accessToken=deadbeef-dead-beef-dead-beefdeadbeef&timestamp=1234567890")!
    )
    request.httpMethod = "POST"
    request.httpBody = try? encoder.encode(
      ServerRoute.Api.Route.Games.SubmitRequest(
        gameContext: .solo(.init(gameMode: .timed, language: .en, puzzle: puzzle)),
        moves: moves
      )
    )
    request.allHTTPHeaderFields = [
      "X-Signature": Data(
        """
        \(String(decoding: request.httpBody!, as: UTF8.self))----SECRET_DEADBEEF----1234567890
        """.utf8
      ).base64EncodedString()
    ]

    var environment = ServerEnvironment.testValue
    environment.database.fetchPlayerByAccessToken = { _ in pure(player) }
    environment.database.submitLeaderboardScore = { score in
      XCTAssertNoDifference(
        score,
        .init(
          dailyChallengeId: nil,
          gameContext: .solo,
          gameMode: .timed,
          language: .en,
          moves: moves,
          playerId: player.id,
          puzzle: puzzle,
          score: 27,
          words: [.init(moveIndex: 0, score: 27, word: "CAB")]
        )
      )
      return pure(
        .init(
          createdAt: Date(timeIntervalSince1970: 1_234_567_890),
          dailyChallengeId: nil,
          gameContext: .solo,
          gameMode: score.gameMode,
          id: .init(rawValue: UUID(uuidString: "deadbeef-dead-beef-dead-beefdeadbeef")!),
          language: score.language,
          moves: score.moves,
          playerId: score.playerId,
          puzzle: score.puzzle,
          score: score.score
        )
      )
    }
    environment.database.fetchLeaderboardSummary = { request in
      switch request.timeScope {
      case .allTime:
        return pure(.init(outOf: 10000, rank: 200))
      case .lastDay:
        return pure(.init(outOf: 100, rank: 2))
      case .lastWeek:
        return pure(.init(outOf: 1000, rank: 50))
      case .interesting:
        return throwE(unit)
      }
    }
    environment.dictionary = .everyString
    environment.router = .test

    let middleware = siteMiddleware(environment: environment)
    let result = middleware(connection(from: request)).perform()

    assertInlineSnapshot(of: result, as: .conn) {
      """
      POST /api/games?accessToken=deadbeef-dead-beef-dead-beefdeadbeef&timestamp=1234567890
      X-Signature: eyJnYW1lQ29udGV4dCI6eyJzb2xvIjp7ImdhbWVNb2RlIjoidGltZWQiLCJsYW5ndWFnZSI6ImVuIiwicHV6emxlIjpbW1t7ImxlZnQiOnsibGV0dGVyIjoiQSIsInNpZGUiOjF9LCJyaWdodCI6eyJsZXR0ZXIiOiJCIiwic2lkZSI6Mn0sInRvcCI6eyJsZXR0ZXIiOiJDIiwic2lkZSI6MH19LHsibGVmdCI6eyJsZXR0ZXIiOiJBIiwic2lkZSI6MX0sInJpZ2h0Ijp7ImxldHRlciI6IkIiLCJzaWRlIjoyfSwidG9wIjp7ImxldHRlciI6IkMiLCJzaWRlIjowfX0seyJsZWZ0Ijp7ImxldHRlciI6IkEiLCJzaWRlIjoxfSwicmlnaHQiOnsibGV0dGVyIjoiQiIsInNpZGUiOjJ9LCJ0b3AiOnsibGV0dGVyIjoiQyIsInNpZGUiOjB9fV0sW3sibGVmdCI6eyJsZXR0ZXIiOiJBIiwic2lkZSI6MX0sInJpZ2h0Ijp7ImxldHRlciI6IkIiLCJzaWRlIjoyfSwidG9wIjp7ImxldHRlciI6IkMiLCJzaWRlIjowfX0seyJsZWZ0Ijp7ImxldHRlciI6IkEiLCJzaWRlIjoxfSwicmlnaHQiOnsibGV0dGVyIjoiQiIsInNpZGUiOjJ9LCJ0b3AiOnsibGV0dGVyIjoiQyIsInNpZGUiOjB9fSx7ImxlZnQiOnsibGV0dGVyIjoiQSIsInNpZGUiOjF9LCJyaWdodCI6eyJsZXR0ZXIiOiJCIiwic2lkZSI6Mn0sInRvcCI6eyJsZXR0ZXIiOiJDIiwic2lkZSI6MH19XSxbeyJsZWZ0Ijp7ImxldHRlciI6IkEiLCJzaWRlIjoxfSwicmlnaHQiOnsibGV0dGVyIjoiQiIsInNpZGUiOjJ9LCJ0b3AiOnsibGV0dGVyIjoiQyIsInNpZGUiOjB9fSx7ImxlZnQiOnsibGV0dGVyIjoiQSIsInNpZGUiOjF9LCJyaWdodCI6eyJsZXR0ZXIiOiJCIiwic2lkZSI6Mn0sInRvcCI6eyJsZXR0ZXIiOiJDIiwic2lkZSI6MH19LHsibGVmdCI6eyJsZXR0ZXIiOiJBIiwic2lkZSI6MX0sInJpZ2h0Ijp7ImxldHRlciI6IkIiLCJzaWRlIjoyfSwidG9wIjp7ImxldHRlciI6IkMiLCJzaWRlIjowfX1dXSxbW3sibGVmdCI6eyJsZXR0ZXIiOiJBIiwic2lkZSI6MX0sInJpZ2h0Ijp7ImxldHRlciI6IkIiLCJzaWRlIjoyfSwidG9wIjp7ImxldHRlciI6IkMiLCJzaWRlIjowfX0seyJsZWZ0Ijp7ImxldHRlciI6IkEiLCJzaWRlIjoxfSwicmlnaHQiOnsibGV0dGVyIjoiQiIsInNpZGUiOjJ9LCJ0b3AiOnsibGV0dGVyIjoiQyIsInNpZGUiOjB9fSx7ImxlZnQiOnsibGV0dGVyIjoiQSIsInNpZGUiOjF9LCJyaWdodCI6eyJsZXR0ZXIiOiJCIiwic2lkZSI6Mn0sInRvcCI6eyJsZXR0ZXIiOiJDIiwic2lkZSI6MH19XSxbeyJsZWZ0Ijp7ImxldHRlciI6IkEiLCJzaWRlIjoxfSwicmlnaHQiOnsibGV0dGVyIjoiQiIsInNpZGUiOjJ9LCJ0b3AiOnsibGV0dGVyIjoiQyIsInNpZGUiOjB9fSx7ImxlZnQiOnsibGV0dGVyIjoiQSIsInNpZGUiOjF9LCJyaWdodCI6eyJsZXR0ZXIiOiJCIiwic2lkZSI6Mn0sInRvcCI6eyJsZXR0ZXIiOiJDIiwic2lkZSI6MH19LHsibGVmdCI6eyJsZXR0ZXIiOiJBIiwic2lkZSI6MX0sInJpZ2h0Ijp7ImxldHRlciI6IkIiLCJzaWRlIjoyfSwidG9wIjp7ImxldHRlciI6IkMiLCJzaWRlIjowfX1dLFt7ImxlZnQiOnsibGV0dGVyIjoiQSIsInNpZGUiOjF9LCJyaWdodCI6eyJsZXR0ZXIiOiJCIiwic2lkZSI6Mn0sInRvcCI6eyJsZXR0ZXIiOiJDIiwic2lkZSI6MH19LHsibGVmdCI6eyJsZXR0ZXIiOiJBIiwic2lkZSI6MX0sInJpZ2h0Ijp7ImxldHRlciI6IkIiLCJzaWRlIjoyfSwidG9wIjp7ImxldHRlciI6IkMiLCJzaWRlIjowfX0seyJsZWZ0Ijp7ImxldHRlciI6IkEiLCJzaWRlIjoxfSwicmlnaHQiOnsibGV0dGVyIjoiQiIsInNpZGUiOjJ9LCJ0b3AiOnsibGV0dGVyIjoiQyIsInNpZGUiOjB9fV1dLFtbeyJsZWZ0Ijp7ImxldHRlciI6IkEiLCJzaWRlIjoxfSwicmlnaHQiOnsibGV0dGVyIjoiQiIsInNpZGUiOjJ9LCJ0b3AiOnsibGV0dGVyIjoiQyIsInNpZGUiOjB9fSx7ImxlZnQiOnsibGV0dGVyIjoiQSIsInNpZGUiOjF9LCJyaWdodCI6eyJsZXR0ZXIiOiJCIiwic2lkZSI6Mn0sInRvcCI6eyJsZXR0ZXIiOiJDIiwic2lkZSI6MH19LHsibGVmdCI6eyJsZXR0ZXIiOiJBIiwic2lkZSI6MX0sInJpZ2h0Ijp7ImxldHRlciI6IkIiLCJzaWRlIjoyfSwidG9wIjp7ImxldHRlciI6IkMiLCJzaWRlIjowfX1dLFt7ImxlZnQiOnsibGV0dGVyIjoiQSIsInNpZGUiOjF9LCJyaWdodCI6eyJsZXR0ZXIiOiJCIiwic2lkZSI6Mn0sInRvcCI6eyJsZXR0ZXIiOiJDIiwic2lkZSI6MH19LHsibGVmdCI6eyJsZXR0ZXIiOiJBIiwic2lkZSI6MX0sInJpZ2h0Ijp7ImxldHRlciI6IkIiLCJzaWRlIjoyfSwidG9wIjp7ImxldHRlciI6IkMiLCJzaWRlIjowfX0seyJsZWZ0Ijp7ImxldHRlciI6IkEiLCJzaWRlIjoxfSwicmlnaHQiOnsibGV0dGVyIjoiQiIsInNpZGUiOjJ9LCJ0b3AiOnsibGV0dGVyIjoiQyIsInNpZGUiOjB9fV0sW3sibGVmdCI6eyJsZXR0ZXIiOiJBIiwic2lkZSI6MX0sInJpZ2h0Ijp7ImxldHRlciI6IkIiLCJzaWRlIjoyfSwidG9wIjp7ImxldHRlciI6IkMiLCJzaWRlIjowfX0seyJsZWZ0Ijp7ImxldHRlciI6IkEiLCJzaWRlIjoxfSwicmlnaHQiOnsibGV0dGVyIjoiQiIsInNpZGUiOjJ9LCJ0b3AiOnsibGV0dGVyIjoiQyIsInNpZGUiOjB9fSx7ImxlZnQiOnsibGV0dGVyIjoiQSIsInNpZGUiOjF9LCJyaWdodCI6eyJsZXR0ZXIiOiJCIiwic2lkZSI6Mn0sInRvcCI6eyJsZXR0ZXIiOiJDIiwic2lkZSI6MH19XV1dfX0sIm1vdmVzIjpbeyJwbGF5ZWRBdCI6MTIzNDU2Nzg5MC41LCJzY29yZSI6MjcsInR5cGUiOnsicGxheWVkV29yZCI6W3siaW5kZXgiOnsieCI6MiwieSI6MiwieiI6Mn0sInNpZGUiOjB9LHsiaW5kZXgiOnsieCI6MiwieSI6MiwieiI6Mn0sInNpZGUiOjF9LHsiaW5kZXgiOnsieCI6MiwieSI6MiwieiI6Mn0sInNpZGUiOjJ9XX19XX0tLS0tU0VDUkVUX0RFQURCRUVGLS0tLTEyMzQ1Njc4OTA=

      {"gameContext":{"solo":{"gameMode":"timed","language":"en","puzzle":[[[{"left":{"letter":"A","side":1},"right":{"letter":"B","side":2},"top":{"letter":"C","side":0}},{"left":{"letter":"A","side":1},"right":{"letter":"B","side":2},"top":{"letter":"C","side":0}},{"left":{"letter":"A","side":1},"right":{"letter":"B","side":2},"top":{"letter":"C","side":0}}],[{"left":{"letter":"A","side":1},"right":{"letter":"B","side":2},"top":{"letter":"C","side":0}},{"left":{"letter":"A","side":1},"right":{"letter":"B","side":2},"top":{"letter":"C","side":0}},{"left":{"letter":"A","side":1},"right":{"letter":"B","side":2},"top":{"letter":"C","side":0}}],[{"left":{"letter":"A","side":1},"right":{"letter":"B","side":2},"top":{"letter":"C","side":0}},{"left":{"letter":"A","side":1},"right":{"letter":"B","side":2},"top":{"letter":"C","side":0}},{"left":{"letter":"A","side":1},"right":{"letter":"B","side":2},"top":{"letter":"C","side":0}}]],[[{"left":{"letter":"A","side":1},"right":{"letter":"B","side":2},"top":{"letter":"C","side":0}},{"left":{"letter":"A","side":1},"right":{"letter":"B","side":2},"top":{"letter":"C","side":0}},{"left":{"letter":"A","side":1},"right":{"letter":"B","side":2},"top":{"letter":"C","side":0}}],[{"left":{"letter":"A","side":1},"right":{"letter":"B","side":2},"top":{"letter":"C","side":0}},{"left":{"letter":"A","side":1},"right":{"letter":"B","side":2},"top":{"letter":"C","side":0}},{"left":{"letter":"A","side":1},"right":{"letter":"B","side":2},"top":{"letter":"C","side":0}}],[{"left":{"letter":"A","side":1},"right":{"letter":"B","side":2},"top":{"letter":"C","side":0}},{"left":{"letter":"A","side":1},"right":{"letter":"B","side":2},"top":{"letter":"C","side":0}},{"left":{"letter":"A","side":1},"right":{"letter":"B","side":2},"top":{"letter":"C","side":0}}]],[[{"left":{"letter":"A","side":1},"right":{"letter":"B","side":2},"top":{"letter":"C","side":0}},{"left":{"letter":"A","side":1},"right":{"letter":"B","side":2},"top":{"letter":"C","side":0}},{"left":{"letter":"A","side":1},"right":{"letter":"B","side":2},"top":{"letter":"C","side":0}}],[{"left":{"letter":"A","side":1},"right":{"letter":"B","side":2},"top":{"letter":"C","side":0}},{"left":{"letter":"A","side":1},"right":{"letter":"B","side":2},"top":{"letter":"C","side":0}},{"left":{"letter":"A","side":1},"right":{"letter":"B","side":2},"top":{"letter":"C","side":0}}],[{"left":{"letter":"A","side":1},"right":{"letter":"B","side":2},"top":{"letter":"C","side":0}},{"left":{"letter":"A","side":1},"right":{"letter":"B","side":2},"top":{"letter":"C","side":0}},{"left":{"letter":"A","side":1},"right":{"letter":"B","side":2},"top":{"letter":"C","side":0}}]]]}},"moves":[{"playedAt":1234567890.5,"score":27,"type":{"playedWord":[{"index":{"x":2,"y":2,"z":2},"side":0},{"index":{"x":2,"y":2,"z":2},"side":1},{"index":{"x":2,"y":2,"z":2},"side":2}]}}]}

      200 OK
      Content-Length: 261
      Content-Type: application/json
      Referrer-Policy: strict-origin-when-cross-origin
      X-Content-Type-Options: nosniff
      X-Download-Options: noopen
      X-Frame-Options: SAMEORIGIN
      X-Permitted-Cross-Domain-Policies: none
      X-XSS-Protection: 1; mode=block

      {
        "solo" : {
          "ranks" : {
            "allTime" : {
              "outOf" : 10000,
              "rank" : 200
            },
            "lastDay" : {
              "outOf" : 100,
              "rank" : 2
            },
            "lastWeek" : {
              "outOf" : 1000,
              "rank" : 50
            }
          }
        }
      }

      """
    }
  }

  func testSubmitLeaderboardScore_DailyChallenge() {
    let player = Player.blob
    let puzzle = ArchivablePuzzle.mock
    let index = LatticePoint(x: .two, y: .two, z: .two)
    let moves: Moves = [
      Move(
        // NB: Fractional second forces same encoding on Linux (Apple platforms omit trailing '.0')
        playedAt: Date(timeIntervalSince1970: 1_234_567_890.5),
        playerIndex: nil,
        reactions: nil,
        score: 27,
        type: .playedWord([
          .init(index: index, side: .top),
          .init(index: index, side: .left),
          .init(index: index, side: .right),
        ])
      )
    ]
    var request = URLRequest(
      url: URL(
        string: "/api/games?accessToken=deadbeef-dead-beef-dead-beefdeadbeef&timestamp=1234567890")!
    )
    request.httpMethod = "POST"
    request.httpBody = try? encoder.encode(
      ServerRoute.Api.Route.Games.SubmitRequest(
        gameContext: .dailyChallenge(.init(rawValue: .dailyChallengeId)),
        moves: moves
      )
    )
    request.allHTTPHeaderFields = [
      "X-Signature": Data(
        """
        \(String(decoding: request.httpBody!, as: UTF8.self))----SECRET_DEADBEEF----1234567890
        """.utf8
      ).base64EncodedString()
    ]

    var environment = ServerEnvironment.testValue
    environment.database.completeDailyChallenge = { _, _ in
      pure(
        DailyChallengePlay(
          completedAt: .mock,
          createdAt: .mock,
          dailyChallengeId: .init(rawValue: .dailyChallengeId),
          id: .init(rawValue: .deadbeef),
          playerId: player.id
        )
      )
    }
    environment.database.fetchDailyChallengeById = { _ in
      pure(
        DailyChallenge(
          createdAt: .mock,
          endsAt: Date(timeIntervalSince1970: 1_234_567_890),
          gameMode: .unlimited,
          gameNumber: 42,
          id: .init(rawValue: .dailyChallengeId),
          language: .en,
          puzzle: puzzle
        )
      )
    }
    environment.database.fetchPlayerByAccessToken = { _ in pure(player) }
    environment.database.submitLeaderboardScore = { score in
      XCTAssertNoDifference(
        score,
        .init(
          dailyChallengeId: .init(rawValue: .dailyChallengeId),
          gameContext: .dailyChallenge,
          gameMode: .unlimited,
          language: .en,
          moves: moves,
          playerId: player.id,
          puzzle: puzzle,
          score: 27,
          words: [.init(moveIndex: 0, score: 27, word: "CAB")]
        )
      )
      return pure(
        .init(
          createdAt: Date(timeIntervalSince1970: 1_234_567_890),
          dailyChallengeId: nil,
          gameContext: .solo,
          gameMode: score.gameMode,
          id: .init(rawValue: UUID(uuidString: "deadbeef-dead-beef-dead-beefdeadbeef")!),
          language: score.language,
          moves: score.moves,
          playerId: score.playerId,
          puzzle: score.puzzle,
          score: score.score
        )
      )
    }
    environment.database.fetchDailyChallengeResult = { _ in
      pure(DailyChallengeResult(outOf: 100, rank: 42, score: nil))
    }
    environment.dictionary = .everyString
    environment.router = .test

    let middleware = siteMiddleware(environment: environment)
    let result = middleware(connection(from: request)).perform()

    assertInlineSnapshot(of: result, as: .conn) {
      """
      POST /api/games?accessToken=deadbeef-dead-beef-dead-beefdeadbeef&timestamp=1234567890
      X-Signature: eyJnYW1lQ29udGV4dCI6eyJkYWlseUNoYWxsZW5nZUlkIjoiREVBREJFRUYtREVBRC1CRUVGLURFQUQtREExMTdDNEExMTMyIn0sIm1vdmVzIjpbeyJwbGF5ZWRBdCI6MTIzNDU2Nzg5MC41LCJzY29yZSI6MjcsInR5cGUiOnsicGxheWVkV29yZCI6W3siaW5kZXgiOnsieCI6MiwieSI6MiwieiI6Mn0sInNpZGUiOjB9LHsiaW5kZXgiOnsieCI6MiwieSI6MiwieiI6Mn0sInNpZGUiOjF9LHsiaW5kZXgiOnsieCI6MiwieSI6MiwieiI6Mn0sInNpZGUiOjJ9XX19XX0tLS0tU0VDUkVUX0RFQURCRUVGLS0tLTEyMzQ1Njc4OTA=

      {"gameContext":{"dailyChallengeId":"DEADBEEF-DEAD-BEEF-DEAD-DA117C4A1132"},"moves":[{"playedAt":1234567890.5,"score":27,"type":{"playedWord":[{"index":{"x":2,"y":2,"z":2},"side":0},{"index":{"x":2,"y":2,"z":2},"side":1},{"index":{"x":2,"y":2,"z":2},"side":2}]}}]}

      200 OK
      Content-Length: 88
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
          "rank" : 42,
          "started" : false
        }
      }

      """
    }
  }

  func testSubmitLeaderboardScore_Shared() {
    let player = Player.blob
    let puzzle = ArchivablePuzzle.mock
    let index = LatticePoint(x: .two, y: .two, z: .two)
    let moves: Moves = [
      Move(
        // NB: Fractional second forces same encoding on Linux (Apple platforms omit trailing '.0')
        playedAt: Date(timeIntervalSince1970: 1_234_567_890.5),
        playerIndex: nil,
        reactions: nil,
        score: 100,
        type: .playedWord([
          .init(index: index, side: .left),
          .init(index: index, side: .right),
          .init(index: index, side: .top),
        ])
      )
    ]
    var request = URLRequest(
      url: URL(
        string: "/api/games?accessToken=deadbeef-dead-beef-dead-beefdeadbeef&timestamp=1234567890")!
    )
    request.httpMethod = "POST"
    request.httpBody = try? encoder.encode(
      ServerRoute.Api.Route.Games.SubmitRequest(
        gameContext: .shared("deadbeef"),
        moves: moves
      )
    )
    request.allHTTPHeaderFields = [
      "X-Signature": Data(
        """
        \(String(decoding: request.httpBody!, as: UTF8.self))----SECRET_DEADBEEF----1234567890
        """.utf8
      ).base64EncodedString()
    ]

    var environment = ServerEnvironment.testValue
    environment.database.fetchPlayerByAccessToken = { _ in pure(player) }
    environment.database.fetchSharedGame = { request in
      pure(
        SharedGame(
          code: "deadbeef",
          createdAt: .mock,
          gameMode: .timed,
          id: .init(rawValue: .deadbeef),
          language: .en,
          moves: .init([]),
          playerId: .init(rawValue: .deadbeef),
          puzzle: puzzle
        )
      )
    }
    environment.router = .test
    let middleware = siteMiddleware(environment: environment)
    let result = middleware(connection(from: request)).perform()

    assertInlineSnapshot(of: result, as: .conn) {
      """
      POST /api/games?accessToken=deadbeef-dead-beef-dead-beefdeadbeef&timestamp=1234567890
      X-Signature: eyJnYW1lQ29udGV4dCI6eyJzaGFyZWRHYW1lQ29kZSI6ImRlYWRiZWVmIn0sIm1vdmVzIjpbeyJwbGF5ZWRBdCI6MTIzNDU2Nzg5MC41LCJzY29yZSI6MTAwLCJ0eXBlIjp7InBsYXllZFdvcmQiOlt7ImluZGV4Ijp7IngiOjIsInkiOjIsInoiOjJ9LCJzaWRlIjoxfSx7ImluZGV4Ijp7IngiOjIsInkiOjIsInoiOjJ9LCJzaWRlIjoyfSx7ImluZGV4Ijp7IngiOjIsInkiOjIsInoiOjJ9LCJzaWRlIjowfV19fV19LS0tLVNFQ1JFVF9ERUFEQkVFRi0tLS0xMjM0NTY3ODkw

      {"gameContext":{"sharedGameCode":"deadbeef"},"moves":[{"playedAt":1234567890.5,"score":100,"type":{"playedWord":[{"index":{"x":2,"y":2,"z":2},"side":1},{"index":{"x":2,"y":2,"z":2},"side":2},{"index":{"x":2,"y":2,"z":2},"side":0}]}}]}

      200 OK
      Content-Length: 8602
      Content-Type: application/json
      Referrer-Policy: strict-origin-when-cross-origin
      X-Content-Type-Options: nosniff
      X-Download-Options: noopen
      X-Frame-Options: SAMEORIGIN
      X-Permitted-Cross-Domain-Policies: none
      X-XSS-Protection: 1; mode=block

      {
        "shared" : {
          "code" : "deadbeef",
          "gameMode" : "timed",
          "id" : "DEADBEEF-DEAD-BEEF-DEAD-BEEFDEADBEEF",
          "language" : "en",
          "moves" : [

          ],
          "puzzle" : [
            [
              [
                {
                  "left" : {
                    "letter" : "A",
                    "side" : 1
                  },
                  "right" : {
                    "letter" : "B",
                    "side" : 2
                  },
                  "top" : {
                    "letter" : "C",
                    "side" : 0
                  }
                },
                {
                  "left" : {
                    "letter" : "A",
                    "side" : 1
                  },
                  "right" : {
                    "letter" : "B",
                    "side" : 2
                  },
                  "top" : {
                    "letter" : "C",
                    "side" : 0
                  }
                },
                {
                  "left" : {
                    "letter" : "A",
                    "side" : 1
                  },
                  "right" : {
                    "letter" : "B",
                    "side" : 2
                  },
                  "top" : {
                    "letter" : "C",
                    "side" : 0
                  }
                }
              ],
              [
                {
                  "left" : {
                    "letter" : "A",
                    "side" : 1
                  },
                  "right" : {
                    "letter" : "B",
                    "side" : 2
                  },
                  "top" : {
                    "letter" : "C",
                    "side" : 0
                  }
                },
                {
                  "left" : {
                    "letter" : "A",
                    "side" : 1
                  },
                  "right" : {
                    "letter" : "B",
                    "side" : 2
                  },
                  "top" : {
                    "letter" : "C",
                    "side" : 0
                  }
                },
                {
                  "left" : {
                    "letter" : "A",
                    "side" : 1
                  },
                  "right" : {
                    "letter" : "B",
                    "side" : 2
                  },
                  "top" : {
                    "letter" : "C",
                    "side" : 0
                  }
                }
              ],
              [
                {
                  "left" : {
                    "letter" : "A",
                    "side" : 1
                  },
                  "right" : {
                    "letter" : "B",
                    "side" : 2
                  },
                  "top" : {
                    "letter" : "C",
                    "side" : 0
                  }
                },
                {
                  "left" : {
                    "letter" : "A",
                    "side" : 1
                  },
                  "right" : {
                    "letter" : "B",
                    "side" : 2
                  },
                  "top" : {
                    "letter" : "C",
                    "side" : 0
                  }
                },
                {
                  "left" : {
                    "letter" : "A",
                    "side" : 1
                  },
                  "right" : {
                    "letter" : "B",
                    "side" : 2
                  },
                  "top" : {
                    "letter" : "C",
                    "side" : 0
                  }
                }
              ]
            ],
            [
              [
                {
                  "left" : {
                    "letter" : "A",
                    "side" : 1
                  },
                  "right" : {
                    "letter" : "B",
                    "side" : 2
                  },
                  "top" : {
                    "letter" : "C",
                    "side" : 0
                  }
                },
                {
                  "left" : {
                    "letter" : "A",
                    "side" : 1
                  },
                  "right" : {
                    "letter" : "B",
                    "side" : 2
                  },
                  "top" : {
                    "letter" : "C",
                    "side" : 0
                  }
                },
                {
                  "left" : {
                    "letter" : "A",
                    "side" : 1
                  },
                  "right" : {
                    "letter" : "B",
                    "side" : 2
                  },
                  "top" : {
                    "letter" : "C",
                    "side" : 0
                  }
                }
              ],
              [
                {
                  "left" : {
                    "letter" : "A",
                    "side" : 1
                  },
                  "right" : {
                    "letter" : "B",
                    "side" : 2
                  },
                  "top" : {
                    "letter" : "C",
                    "side" : 0
                  }
                },
                {
                  "left" : {
                    "letter" : "A",
                    "side" : 1
                  },
                  "right" : {
                    "letter" : "B",
                    "side" : 2
                  },
                  "top" : {
                    "letter" : "C",
                    "side" : 0
                  }
                },
                {
                  "left" : {
                    "letter" : "A",
                    "side" : 1
                  },
                  "right" : {
                    "letter" : "B",
                    "side" : 2
                  },
                  "top" : {
                    "letter" : "C",
                    "side" : 0
                  }
                }
              ],
              [
                {
                  "left" : {
                    "letter" : "A",
                    "side" : 1
                  },
                  "right" : {
                    "letter" : "B",
                    "side" : 2
                  },
                  "top" : {
                    "letter" : "C",
                    "side" : 0
                  }
                },
                {
                  "left" : {
                    "letter" : "A",
                    "side" : 1
                  },
                  "right" : {
                    "letter" : "B",
                    "side" : 2
                  },
                  "top" : {
                    "letter" : "C",
                    "side" : 0
                  }
                },
                {
                  "left" : {
                    "letter" : "A",
                    "side" : 1
                  },
                  "right" : {
                    "letter" : "B",
                    "side" : 2
                  },
                  "top" : {
                    "letter" : "C",
                    "side" : 0
                  }
                }
              ]
            ],
            [
              [
                {
                  "left" : {
                    "letter" : "A",
                    "side" : 1
                  },
                  "right" : {
                    "letter" : "B",
                    "side" : 2
                  },
                  "top" : {
                    "letter" : "C",
                    "side" : 0
                  }
                },
                {
                  "left" : {
                    "letter" : "A",
                    "side" : 1
                  },
                  "right" : {
                    "letter" : "B",
                    "side" : 2
                  },
                  "top" : {
                    "letter" : "C",
                    "side" : 0
                  }
                },
                {
                  "left" : {
                    "letter" : "A",
                    "side" : 1
                  },
                  "right" : {
                    "letter" : "B",
                    "side" : 2
                  },
                  "top" : {
                    "letter" : "C",
                    "side" : 0
                  }
                }
              ],
              [
                {
                  "left" : {
                    "letter" : "A",
                    "side" : 1
                  },
                  "right" : {
                    "letter" : "B",
                    "side" : 2
                  },
                  "top" : {
                    "letter" : "C",
                    "side" : 0
                  }
                },
                {
                  "left" : {
                    "letter" : "A",
                    "side" : 1
                  },
                  "right" : {
                    "letter" : "B",
                    "side" : 2
                  },
                  "top" : {
                    "letter" : "C",
                    "side" : 0
                  }
                },
                {
                  "left" : {
                    "letter" : "A",
                    "side" : 1
                  },
                  "right" : {
                    "letter" : "B",
                    "side" : 2
                  },
                  "top" : {
                    "letter" : "C",
                    "side" : 0
                  }
                }
              ],
              [
                {
                  "left" : {
                    "letter" : "A",
                    "side" : 1
                  },
                  "right" : {
                    "letter" : "B",
                    "side" : 2
                  },
                  "top" : {
                    "letter" : "C",
                    "side" : 0
                  }
                },
                {
                  "left" : {
                    "letter" : "A",
                    "side" : 1
                  },
                  "right" : {
                    "letter" : "B",
                    "side" : 2
                  },
                  "top" : {
                    "letter" : "C",
                    "side" : 0
                  }
                },
                {
                  "left" : {
                    "letter" : "A",
                    "side" : 1
                  },
                  "right" : {
                    "letter" : "B",
                    "side" : 2
                  },
                  "top" : {
                    "letter" : "C",
                    "side" : 0
                  }
                }
              ]
            ]
          ]
        }
      }

      """
    }
  }

  func testSubmitLeaderboardScore_TurnBased() {
    let player = Player.blob
    let opponent = Player.blobJr
    let puzzle = ArchivablePuzzle.mock
    let index = LatticePoint(x: .two, y: .two, z: .two)
    let moves: Moves = [
      Move(
        // NB: Fractional second forces same encoding on Linux (Apple platforms omit trailing '.0')
        playedAt: Date(timeIntervalSince1970: 1_234_567_890.5),
        playerIndex: 1,
        reactions: nil,
        score: 27,
        type: .playedWord([
          .init(index: index, side: .left),
          .init(index: index, side: .right),
          .init(index: index, side: .top),
        ])
      ),
      Move(
        // NB: Fractional second forces same encoding on Linux (Apple platforms omit trailing '.0')
        playedAt: Date(timeIntervalSince1970: 1_234_567_890.5),
        playerIndex: 0,
        reactions: nil,
        score: 27,
        type: .playedWord([
          .init(index: index, side: .top),
          .init(index: index, side: .left),
          .init(index: index, side: .right),
        ])
      ),
    ]
    var request = URLRequest(
      url: URL(
        string: "/api/games?accessToken=deadbeef-dead-beef-dead-beefdeadbeef&timestamp=1234567890")!
    )
    request.httpMethod = "POST"
    request.httpBody = try? encoder.encode(
      ServerRoute.Api.Route.Games.SubmitRequest(
        gameContext: .turnBased(
          ServerRoute.Api.Route.Games.SubmitRequest.GameContext.TurnBased(
            gameMode: .unlimited,
            language: .en,
            playerIndexToId: [
              0: player.id,
              1: opponent.id,
            ],
            puzzle: puzzle
          )
        ),
        moves: moves
      )
    )
    request.allHTTPHeaderFields = [
      "X-Signature": Data(
        """
        \(String(decoding: request.httpBody!, as: UTF8.self))----SECRET_DEADBEEF----1234567890
        """.utf8
      ).base64EncodedString()
    ]

    var scores: [DatabaseClient.SubmitLeaderboardScore] = []
    var environment = ServerEnvironment.testValue
    environment.database.fetchPlayerByAccessToken = { _ in pure(player) }
    environment.database.submitLeaderboardScore = { score in
      scores.append(score)
      return pure(
        .init(
          createdAt: Date(timeIntervalSince1970: 1_234_567_890),
          dailyChallengeId: nil,
          gameContext: .turnBased,
          gameMode: score.gameMode,
          id: .init(rawValue: UUID(uuidString: "deadbeef-dead-beef-dead-beefdeadbeef")!),
          language: score.language,
          moves: score.moves,
          playerId: score.playerId,
          puzzle: score.puzzle,
          score: score.score
        )
      )
    }
    environment.dictionary = .everyString
    environment.router = .test

    let middleware = siteMiddleware(environment: environment)
    let result = middleware(connection(from: request)).perform()

    assertInlineSnapshot(of: result, as: .conn) {
      """
      POST /api/games?accessToken=deadbeef-dead-beef-dead-beefdeadbeef&timestamp=1234567890
      X-Signature: eyJnYW1lQ29udGV4dCI6eyJ0dXJuQmFzZWQiOnsiZ2FtZU1vZGUiOiJ1bmxpbWl0ZWQiLCJsYW5ndWFnZSI6ImVuIiwicGxheWVySW5kZXhUb0lkIjp7IjAiOiJCMTBCQjEwQi1ERUFELUJFRUYtREVBRC1CRUVGREVBREJFRUYiLCIxIjoiQjEwQjIwMDAtREVBRC1CRUVGLURFQUQtQkVFRkRFQURCRUVGIn0sInB1enpsZSI6W1tbeyJsZWZ0Ijp7ImxldHRlciI6IkEiLCJzaWRlIjoxfSwicmlnaHQiOnsibGV0dGVyIjoiQiIsInNpZGUiOjJ9LCJ0b3AiOnsibGV0dGVyIjoiQyIsInNpZGUiOjB9fSx7ImxlZnQiOnsibGV0dGVyIjoiQSIsInNpZGUiOjF9LCJyaWdodCI6eyJsZXR0ZXIiOiJCIiwic2lkZSI6Mn0sInRvcCI6eyJsZXR0ZXIiOiJDIiwic2lkZSI6MH19LHsibGVmdCI6eyJsZXR0ZXIiOiJBIiwic2lkZSI6MX0sInJpZ2h0Ijp7ImxldHRlciI6IkIiLCJzaWRlIjoyfSwidG9wIjp7ImxldHRlciI6IkMiLCJzaWRlIjowfX1dLFt7ImxlZnQiOnsibGV0dGVyIjoiQSIsInNpZGUiOjF9LCJyaWdodCI6eyJsZXR0ZXIiOiJCIiwic2lkZSI6Mn0sInRvcCI6eyJsZXR0ZXIiOiJDIiwic2lkZSI6MH19LHsibGVmdCI6eyJsZXR0ZXIiOiJBIiwic2lkZSI6MX0sInJpZ2h0Ijp7ImxldHRlciI6IkIiLCJzaWRlIjoyfSwidG9wIjp7ImxldHRlciI6IkMiLCJzaWRlIjowfX0seyJsZWZ0Ijp7ImxldHRlciI6IkEiLCJzaWRlIjoxfSwicmlnaHQiOnsibGV0dGVyIjoiQiIsInNpZGUiOjJ9LCJ0b3AiOnsibGV0dGVyIjoiQyIsInNpZGUiOjB9fV0sW3sibGVmdCI6eyJsZXR0ZXIiOiJBIiwic2lkZSI6MX0sInJpZ2h0Ijp7ImxldHRlciI6IkIiLCJzaWRlIjoyfSwidG9wIjp7ImxldHRlciI6IkMiLCJzaWRlIjowfX0seyJsZWZ0Ijp7ImxldHRlciI6IkEiLCJzaWRlIjoxfSwicmlnaHQiOnsibGV0dGVyIjoiQiIsInNpZGUiOjJ9LCJ0b3AiOnsibGV0dGVyIjoiQyIsInNpZGUiOjB9fSx7ImxlZnQiOnsibGV0dGVyIjoiQSIsInNpZGUiOjF9LCJyaWdodCI6eyJsZXR0ZXIiOiJCIiwic2lkZSI6Mn0sInRvcCI6eyJsZXR0ZXIiOiJDIiwic2lkZSI6MH19XV0sW1t7ImxlZnQiOnsibGV0dGVyIjoiQSIsInNpZGUiOjF9LCJyaWdodCI6eyJsZXR0ZXIiOiJCIiwic2lkZSI6Mn0sInRvcCI6eyJsZXR0ZXIiOiJDIiwic2lkZSI6MH19LHsibGVmdCI6eyJsZXR0ZXIiOiJBIiwic2lkZSI6MX0sInJpZ2h0Ijp7ImxldHRlciI6IkIiLCJzaWRlIjoyfSwidG9wIjp7ImxldHRlciI6IkMiLCJzaWRlIjowfX0seyJsZWZ0Ijp7ImxldHRlciI6IkEiLCJzaWRlIjoxfSwicmlnaHQiOnsibGV0dGVyIjoiQiIsInNpZGUiOjJ9LCJ0b3AiOnsibGV0dGVyIjoiQyIsInNpZGUiOjB9fV0sW3sibGVmdCI6eyJsZXR0ZXIiOiJBIiwic2lkZSI6MX0sInJpZ2h0Ijp7ImxldHRlciI6IkIiLCJzaWRlIjoyfSwidG9wIjp7ImxldHRlciI6IkMiLCJzaWRlIjowfX0seyJsZWZ0Ijp7ImxldHRlciI6IkEiLCJzaWRlIjoxfSwicmlnaHQiOnsibGV0dGVyIjoiQiIsInNpZGUiOjJ9LCJ0b3AiOnsibGV0dGVyIjoiQyIsInNpZGUiOjB9fSx7ImxlZnQiOnsibGV0dGVyIjoiQSIsInNpZGUiOjF9LCJyaWdodCI6eyJsZXR0ZXIiOiJCIiwic2lkZSI6Mn0sInRvcCI6eyJsZXR0ZXIiOiJDIiwic2lkZSI6MH19XSxbeyJsZWZ0Ijp7ImxldHRlciI6IkEiLCJzaWRlIjoxfSwicmlnaHQiOnsibGV0dGVyIjoiQiIsInNpZGUiOjJ9LCJ0b3AiOnsibGV0dGVyIjoiQyIsInNpZGUiOjB9fSx7ImxlZnQiOnsibGV0dGVyIjoiQSIsInNpZGUiOjF9LCJyaWdodCI6eyJsZXR0ZXIiOiJCIiwic2lkZSI6Mn0sInRvcCI6eyJsZXR0ZXIiOiJDIiwic2lkZSI6MH19LHsibGVmdCI6eyJsZXR0ZXIiOiJBIiwic2lkZSI6MX0sInJpZ2h0Ijp7ImxldHRlciI6IkIiLCJzaWRlIjoyfSwidG9wIjp7ImxldHRlciI6IkMiLCJzaWRlIjowfX1dXSxbW3sibGVmdCI6eyJsZXR0ZXIiOiJBIiwic2lkZSI6MX0sInJpZ2h0Ijp7ImxldHRlciI6IkIiLCJzaWRlIjoyfSwidG9wIjp7ImxldHRlciI6IkMiLCJzaWRlIjowfX0seyJsZWZ0Ijp7ImxldHRlciI6IkEiLCJzaWRlIjoxfSwicmlnaHQiOnsibGV0dGVyIjoiQiIsInNpZGUiOjJ9LCJ0b3AiOnsibGV0dGVyIjoiQyIsInNpZGUiOjB9fSx7ImxlZnQiOnsibGV0dGVyIjoiQSIsInNpZGUiOjF9LCJyaWdodCI6eyJsZXR0ZXIiOiJCIiwic2lkZSI6Mn0sInRvcCI6eyJsZXR0ZXIiOiJDIiwic2lkZSI6MH19XSxbeyJsZWZ0Ijp7ImxldHRlciI6IkEiLCJzaWRlIjoxfSwicmlnaHQiOnsibGV0dGVyIjoiQiIsInNpZGUiOjJ9LCJ0b3AiOnsibGV0dGVyIjoiQyIsInNpZGUiOjB9fSx7ImxlZnQiOnsibGV0dGVyIjoiQSIsInNpZGUiOjF9LCJyaWdodCI6eyJsZXR0ZXIiOiJCIiwic2lkZSI6Mn0sInRvcCI6eyJsZXR0ZXIiOiJDIiwic2lkZSI6MH19LHsibGVmdCI6eyJsZXR0ZXIiOiJBIiwic2lkZSI6MX0sInJpZ2h0Ijp7ImxldHRlciI6IkIiLCJzaWRlIjoyfSwidG9wIjp7ImxldHRlciI6IkMiLCJzaWRlIjowfX1dLFt7ImxlZnQiOnsibGV0dGVyIjoiQSIsInNpZGUiOjF9LCJyaWdodCI6eyJsZXR0ZXIiOiJCIiwic2lkZSI6Mn0sInRvcCI6eyJsZXR0ZXIiOiJDIiwic2lkZSI6MH19LHsibGVmdCI6eyJsZXR0ZXIiOiJBIiwic2lkZSI6MX0sInJpZ2h0Ijp7ImxldHRlciI6IkIiLCJzaWRlIjoyfSwidG9wIjp7ImxldHRlciI6IkMiLCJzaWRlIjowfX0seyJsZWZ0Ijp7ImxldHRlciI6IkEiLCJzaWRlIjoxfSwicmlnaHQiOnsibGV0dGVyIjoiQiIsInNpZGUiOjJ9LCJ0b3AiOnsibGV0dGVyIjoiQyIsInNpZGUiOjB9fV1dXX19LCJtb3ZlcyI6W3sicGxheWVkQXQiOjEyMzQ1Njc4OTAuNSwicGxheWVySW5kZXgiOjEsInNjb3JlIjoyNywidHlwZSI6eyJwbGF5ZWRXb3JkIjpbeyJpbmRleCI6eyJ4IjoyLCJ5IjoyLCJ6IjoyfSwic2lkZSI6MX0seyJpbmRleCI6eyJ4IjoyLCJ5IjoyLCJ6IjoyfSwic2lkZSI6Mn0seyJpbmRleCI6eyJ4IjoyLCJ5IjoyLCJ6IjoyfSwic2lkZSI6MH1dfX0seyJwbGF5ZWRBdCI6MTIzNDU2Nzg5MC41LCJwbGF5ZXJJbmRleCI6MCwic2NvcmUiOjI3LCJ0eXBlIjp7InBsYXllZFdvcmQiOlt7ImluZGV4Ijp7IngiOjIsInkiOjIsInoiOjJ9LCJzaWRlIjowfSx7ImluZGV4Ijp7IngiOjIsInkiOjIsInoiOjJ9LCJzaWRlIjoxfSx7ImluZGV4Ijp7IngiOjIsInkiOjIsInoiOjJ9LCJzaWRlIjoyfV19fV19LS0tLVNFQ1JFVF9ERUFEQkVFRi0tLS0xMjM0NTY3ODkw

      {"gameContext":{"turnBased":{"gameMode":"unlimited","language":"en","playerIndexToId":{"0":"B10BB10B-DEAD-BEEF-DEAD-BEEFDEADBEEF","1":"B10B2000-DEAD-BEEF-DEAD-BEEFDEADBEEF"},"puzzle":[[[{"left":{"letter":"A","side":1},"right":{"letter":"B","side":2},"top":{"letter":"C","side":0}},{"left":{"letter":"A","side":1},"right":{"letter":"B","side":2},"top":{"letter":"C","side":0}},{"left":{"letter":"A","side":1},"right":{"letter":"B","side":2},"top":{"letter":"C","side":0}}],[{"left":{"letter":"A","side":1},"right":{"letter":"B","side":2},"top":{"letter":"C","side":0}},{"left":{"letter":"A","side":1},"right":{"letter":"B","side":2},"top":{"letter":"C","side":0}},{"left":{"letter":"A","side":1},"right":{"letter":"B","side":2},"top":{"letter":"C","side":0}}],[{"left":{"letter":"A","side":1},"right":{"letter":"B","side":2},"top":{"letter":"C","side":0}},{"left":{"letter":"A","side":1},"right":{"letter":"B","side":2},"top":{"letter":"C","side":0}},{"left":{"letter":"A","side":1},"right":{"letter":"B","side":2},"top":{"letter":"C","side":0}}]],[[{"left":{"letter":"A","side":1},"right":{"letter":"B","side":2},"top":{"letter":"C","side":0}},{"left":{"letter":"A","side":1},"right":{"letter":"B","side":2},"top":{"letter":"C","side":0}},{"left":{"letter":"A","side":1},"right":{"letter":"B","side":2},"top":{"letter":"C","side":0}}],[{"left":{"letter":"A","side":1},"right":{"letter":"B","side":2},"top":{"letter":"C","side":0}},{"left":{"letter":"A","side":1},"right":{"letter":"B","side":2},"top":{"letter":"C","side":0}},{"left":{"letter":"A","side":1},"right":{"letter":"B","side":2},"top":{"letter":"C","side":0}}],[{"left":{"letter":"A","side":1},"right":{"letter":"B","side":2},"top":{"letter":"C","side":0}},{"left":{"letter":"A","side":1},"right":{"letter":"B","side":2},"top":{"letter":"C","side":0}},{"left":{"letter":"A","side":1},"right":{"letter":"B","side":2},"top":{"letter":"C","side":0}}]],[[{"left":{"letter":"A","side":1},"right":{"letter":"B","side":2},"top":{"letter":"C","side":0}},{"left":{"letter":"A","side":1},"right":{"letter":"B","side":2},"top":{"letter":"C","side":0}},{"left":{"letter":"A","side":1},"right":{"letter":"B","side":2},"top":{"letter":"C","side":0}}],[{"left":{"letter":"A","side":1},"right":{"letter":"B","side":2},"top":{"letter":"C","side":0}},{"left":{"letter":"A","side":1},"right":{"letter":"B","side":2},"top":{"letter":"C","side":0}},{"left":{"letter":"A","side":1},"right":{"letter":"B","side":2},"top":{"letter":"C","side":0}}],[{"left":{"letter":"A","side":1},"right":{"letter":"B","side":2},"top":{"letter":"C","side":0}},{"left":{"letter":"A","side":1},"right":{"letter":"B","side":2},"top":{"letter":"C","side":0}},{"left":{"letter":"A","side":1},"right":{"letter":"B","side":2},"top":{"letter":"C","side":0}}]]]}},"moves":[{"playedAt":1234567890.5,"playerIndex":1,"score":27,"type":{"playedWord":[{"index":{"x":2,"y":2,"z":2},"side":1},{"index":{"x":2,"y":2,"z":2},"side":2},{"index":{"x":2,"y":2,"z":2},"side":0}]}},{"playedAt":1234567890.5,"playerIndex":0,"score":27,"type":{"playedWord":[{"index":{"x":2,"y":2,"z":2},"side":0},{"index":{"x":2,"y":2,"z":2},"side":1},{"index":{"x":2,"y":2,"z":2},"side":2}]}}]}

      200 OK
      Content-Length: 24
      Content-Type: application/json
      Referrer-Policy: strict-origin-when-cross-origin
      X-Content-Type-Options: nosniff
      X-Download-Options: noopen
      X-Frame-Options: SAMEORIGIN
      X-Permitted-Cross-Domain-Policies: none
      X-XSS-Protection: 1; mode=block

      {
        "turnBased" : true
      }

      """
    }

    XCTAssertNoDifference(
      scores.sorted(by: { $0.playerId == player.id && $1.playerId != player.id }),
      [
        .init(
          dailyChallengeId: nil,
          gameContext: .turnBased,
          gameMode: .unlimited,
          language: .en,
          moves: moves,
          playerId: player.id,
          puzzle: puzzle,
          score: 27,
          words: [.init(moveIndex: 1, score: 27, word: "CAB")]
        ),
        .init(
          dailyChallengeId: nil,
          gameContext: .turnBased,
          gameMode: .unlimited,
          language: .en,
          moves: moves,
          playerId: opponent.id,
          puzzle: puzzle,
          score: 27,
          words: [.init(moveIndex: 0, score: 27, word: "ABC")]
        ),
      ]
    )
  }
}

private let encoder = { () -> JSONEncoder in
  let encoder = JSONEncoder()
  encoder.dateEncodingStrategy = .secondsSince1970
  encoder.outputFormatting = .sortedKeys
  return encoder
}()
