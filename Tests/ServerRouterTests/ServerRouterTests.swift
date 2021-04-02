import FirstPartyMocks
import Foundation
#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif
import Overture
import SharedModels
import TestHelpers
import XCTest

@testable import ServerRouter

class ServerRouterTests: XCTestCase {
  func testLegacyAuthenticate() throws {
    let json = """
      {
        "deviceId": "deadbeef-dead-beef-dead-beefdeadbeef",
        "displayName": "Blob",
        "gameCenterLocalPlayerId": "token"
      }
      """

    var request = URLRequest(url: URL(string: "http://localhost:9876/api/authenticate")!)
    request.httpMethod = "POST"
    request.httpBody = Data(json.utf8)
    let route = testRouter.match(request: request)

    XCTAssertEqual(
      route,
      .authenticate(
        .init(
          deviceId: .init(rawValue: UUID(uuidString: "deadbeef-dead-beef-dead-beefdeadbeef")!),
          displayName: "Blob",
          gameCenterLocalPlayerId: "token",
          timeZone: "America/New_York"
        )
      )
    )
  }

  func testAuthenticateMatching() throws {
    let json = """
      {
        "deviceId": "deadbeef-dead-beef-dead-beefdeadbeef",
        "displayName": "Blob",
        "gameCenterLocalPlayerId": "token"
      }
      """
    let signature = "\(json)----DEADBEEF----1234567860"

    var request = URLRequest(url: URL(string: "http://localhost:9876/api/authenticate?timestamp=1234567860")!)
    request.httpMethod = "POST"
    request.httpBody = Data(json.utf8)
    request.setValue(testHash(Data(signature.utf8)).base64EncodedString(), forHTTPHeaderField: "X-Signature")
    let route = testRouter.match(request: request)

    XCTAssertEqual(
      route,
      .authenticate(
        .init(
          deviceId: .init(rawValue: UUID(uuidString: "deadbeef-dead-beef-dead-beefdeadbeef")!),
          displayName: "Blob",
          gameCenterLocalPlayerId: "token",
          timeZone: "America/New_York"
        )
      )
    )
  }

  func testAuthenticateMatching_NoDisplayName() throws {
    let json = """
      {
        "deviceId": "deadbeef-dead-beef-dead-beefdeadbeef",
        "gameCenterLocalPlayerId": "token"
      }
      """
    let signature = "\(json)----DEADBEEF----1234567860"

    var request = URLRequest(url: URL(string: "http://localhost:9876/api/authenticate?timestamp=1234567860")!)
    request.httpMethod = "POST"
    request.httpBody = Data(json.utf8)
    request.setValue(testHash(Data(signature.utf8)).base64EncodedString(), forHTTPHeaderField: "X-Signature")
    let route = testRouter.match(request: request)

    XCTAssertEqual(
      route,
      .authenticate(
        .init(
          deviceId: .init(rawValue: UUID(uuidString: "deadbeef-dead-beef-dead-beefdeadbeef")!),
          displayName: nil,
          gameCenterLocalPlayerId: "token",
          timeZone: "America/New_York"
        )
      )
    )
  }

  func testAuthenticateMatching_NoGameCenterId() throws {
    let json = """
      {
        "deviceId": "deadbeef-dead-beef-dead-beefdeadbeef",
        "displayName": "Blob"
      }
      """
    let signature = "\(json)----DEADBEEF----1234567860"

    var request = URLRequest(url: URL(string: "http://localhost:9876/api/authenticate?timestamp=1234567860")!)
    request.httpMethod = "POST"
    request.httpBody = Data(json.utf8)
    request.setValue(testHash(Data(signature.utf8)).base64EncodedString(), forHTTPHeaderField: "X-Signature")
    let route = testRouter.match(request: request)

    XCTAssertEqual(
      route,
      .authenticate(
        .init(
          deviceId: .init(rawValue: UUID(uuidString: "deadbeef-dead-beef-dead-beefdeadbeef")!),
          displayName: "Blob",
          gameCenterLocalPlayerId: nil,
          timeZone: "America/New_York"
        )
      )
    )
  }

  func testAuthenticateMatching_NoDisplayName_NoGameCenterId() throws {
    let json = """
      {
        "deviceId": "deadbeef-dead-beef-dead-beefdeadbeef"
      }
      """
    let signature = "\(json)----DEADBEEF----1234567860"

    var request = URLRequest(url: URL(string: "http://localhost:9876/api/authenticate?timestamp=1234567860")!)
    request.httpMethod = "POST"
    request.httpBody = Data(json.utf8)
    request.setValue(testHash(Data(signature.utf8)).base64EncodedString(), forHTTPHeaderField: "X-Signature")
    let route = testRouter.match(request: request)

    XCTAssertEqual(
      route,
      .authenticate(
        .init(
          deviceId: .init(rawValue: UUID(uuidString: "deadbeef-dead-beef-dead-beefdeadbeef")!),
          displayName: nil,
          gameCenterLocalPlayerId: nil,
          timeZone: "America/New_York"
        )
      )
    )
  }

  func testTodaysDailyChallenges_WithAccessToken() throws {
    let request = URLRequest(
      url: URL(
        string:
          "http://localhost:9876/api/daily-challenges/today?accessToken=deadbeef-dead-beef-dead-beefdeadbeef&language=en"
      )!)
    let route = testRouter.match(request: request)

    XCTAssertEqual(
      route,
      .api(
        .init(
          accessToken: .init(rawValue: UUID(uuidString: "deadbeef-dead-beef-dead-beefdeadbeef")!),
          isDebug: false,
          route: .dailyChallenge(.today(language: .en))
        )
      )
    )
  }

  func testTodaysDailyChallenges_WithoutAccessToken() throws {
    let request = URLRequest(
      url: URL(string: "http://localhost:9876/api/daily-challenges/today?language=en")!)
    let route = testRouter.match(request: request)

    XCTAssertNil(route)
  }

  func testSubmitGame_Demo() throws {
    let submitRequestJson = """
      {"gameMode":"timed","score":1000}
      """
    let submitRequest = try decoder.decode(
      ServerRoute.Demo.SubmitRequest.self,
      from: Data(submitRequestJson.utf8)
    )

    var request = URLRequest(url: URL(string: "http://localhost:9876/demo/games")!)
    request.httpMethod = "POST"
    request.httpBody = Data(submitRequestJson.utf8)
    let route = testRouter.match(request: request)

    XCTAssertEqual(
      route,
      .demo(.submitGame(.init(gameMode: .timed, score: 1_000)))
    )

    let routerRequest = testRouter.request(
      for: .demo(.submitGame(submitRequest)),
      base: URL(string: "http://localhost:9876")!
    )

    XCTAssertEqual(
      routerRequest,
      request
    )
  }

  func testSubmitGame_DailyChallenge() throws {
    let submitRequestJson = """
      {"gameContext":{"dailyChallengeId":"DEADBEEF-DEAD-BEEF-DEAD-BEEFDEADBEEF"},"moves":[{"playedAt":0,"score":10,"type":{"playedWord":[{"index":{"x":0,"y":0,"z":0},"side":0},{"index":{"x":0,"y":0,"z":0},"side":1},{"index":{"x":0,"y":0,"z":0},"side":2}]}},{"playedAt":0,"score":20,"type":{"removedCube":{"x":1,"y":1,"z":1}}}]}
      """
    let submitRequest = try decoder.decode(
      ServerRoute.Api.Route.Games.SubmitRequest.self,
      from: Data(submitRequestJson.utf8)
    )
    let signature = testHash(Data("\(submitRequestJson)----DEADBEEF----1234567890".utf8))

    var request = URLRequest(
      url: URL(
        string:
          "http://localhost:9876/api/games?accessToken=DEADBEEF-DEAD-BEEF-DEAD-BEEFDEADBEEF&timestamp=1234567890"
      )!)
    request.httpMethod = "POST"
    request.httpBody = Data(submitRequestJson.utf8)
    request.allHTTPHeaderFields = [
      "X-Debug": "false",
      "X-Signature": signature.base64EncodedString(),
    ]
    let route = testRouter.match(request: request)

    XCTAssertEqual(
      route,
      .api(
        .init(
          accessToken: .init(rawValue: .deadbeef),
          isDebug: false,
          route: .games(.submit(submitRequest))
        )
      )
    )

    let routerRequest = testRouter.request(
      for: .api(
        .init(
          accessToken: .init(rawValue: .deadbeef),
          isDebug: false,
          route: .games(.submit(submitRequest))
        )
      ),
      base: URL(string: "http://localhost:9876")!
    )

    XCTAssertEqual(
      routerRequest,
      request
    )
  }

  func testSubmitGame_DailyChallenge_LateSignatureTimestamp() throws {
    let submitRequestJson = """
      {"gameContext":{"dailyChallengeId":"DEADBEEF-DEAD-BEEF-DEAD-BEEFDEADBEEF"},"moves":[]}
      """
    // NB: we are submitting the timestamp of 1234567860 when the current timestamp of the router
    //     is 1234567890. This should cause signature verification to fail.
    var signature = "\(submitRequestJson)----DEADBEEF----1234567860"

    var request = URLRequest(
      url: URL(
        string:
          "http://localhost:9876/api/games?accessToken=DEADBEEF-DEAD-BEEF-DEAD-BEEFDEADBEEF&timestamp=1234567860"
      )!)
    request.httpMethod = "POST"
    request.httpBody = Data(submitRequestJson.utf8)
    request.allHTTPHeaderFields = [
      "X-Signature": testHash(Data(signature.utf8)).base64EncodedString()
    ]
    XCTAssertEqual(testRouter.match(request: request), nil)

    // NB: Retry again but with proper timestamp
    request.url = URL(
      string:
        "http://localhost:9876/api/games?accessToken=DEADBEEF-DEAD-BEEF-DEAD-BEEFDEADBEEF&timestamp=1234567890"
    )
    signature = signature.dropLast(2) + "90"
    request.allHTTPHeaderFields = [
      "X-Signature": testHash(Data(signature.utf8)).base64EncodedString()
    ]
    XCTAssertEqual(
      testRouter.match(request: request),
      .api(
        .init(
          accessToken: .init(rawValue: .deadbeef),
          isDebug: false,
          route: .games(
            .submit(.init(gameContext: .dailyChallenge(.init(rawValue: .deadbeef)), moves: []))
          )
        )
      )
    )
  }

  func testFetchLeaderboard() {
    XCTAssertEqual(
      testRouter.match(
        request: URLRequest(
          url: URL(
            string:
              "http://localhost:9876/api/leaderboard-scores?accessToken=deadbeef-dead-beef-dead-beefdeadbeef&gameMode=unlimited&language=en&timeScope=allTime"
          )!
        )
      ),
      .api(
        .init(
          accessToken: .init(rawValue: UUID(uuidString: "deadbeef-dead-beef-dead-beefdeadbeef")!),
          isDebug: false,
          route: .leaderboard(
            .fetch(
              gameMode: .unlimited,
              language: .en,
              timeScope: .allTime
            )
          )
        )
      )
    )
  }

  func testSubmitGame_Solo() throws {
    let submitRequestJson = """
      {"gameContext":{"solo":{"gameMode":"unlimited","language":"en","puzzle":[[[{"left":{"letter":"A","side":1},"right":{"letter":"B","side":2},"top":{"letter":"C","side":0}},{"left":{"letter":"A","side":1},"right":{"letter":"B","side":2},"top":{"letter":"C","side":0}},{"left":{"letter":"A","side":1},"right":{"letter":"B","side":2},"top":{"letter":"C","side":0}}],[{"left":{"letter":"A","side":1},"right":{"letter":"B","side":2},"top":{"letter":"C","side":0}},{"left":{"letter":"A","side":1},"right":{"letter":"B","side":2},"top":{"letter":"C","side":0}},{"left":{"letter":"A","side":1},"right":{"letter":"B","side":2},"top":{"letter":"C","side":0}}],[{"left":{"letter":"A","side":1},"right":{"letter":"B","side":2},"top":{"letter":"C","side":0}},{"left":{"letter":"A","side":1},"right":{"letter":"B","side":2},"top":{"letter":"C","side":0}},{"left":{"letter":"A","side":1},"right":{"letter":"B","side":2},"top":{"letter":"C","side":0}}]],[[{"left":{"letter":"A","side":1},"right":{"letter":"B","side":2},"top":{"letter":"C","side":0}},{"left":{"letter":"A","side":1},"right":{"letter":"B","side":2},"top":{"letter":"C","side":0}},{"left":{"letter":"A","side":1},"right":{"letter":"B","side":2},"top":{"letter":"C","side":0}}],[{"left":{"letter":"A","side":1},"right":{"letter":"B","side":2},"top":{"letter":"C","side":0}},{"left":{"letter":"A","side":1},"right":{"letter":"B","side":2},"top":{"letter":"C","side":0}},{"left":{"letter":"A","side":1},"right":{"letter":"B","side":2},"top":{"letter":"C","side":0}}],[{"left":{"letter":"A","side":1},"right":{"letter":"B","side":2},"top":{"letter":"C","side":0}},{"left":{"letter":"A","side":1},"right":{"letter":"B","side":2},"top":{"letter":"C","side":0}},{"left":{"letter":"A","side":1},"right":{"letter":"B","side":2},"top":{"letter":"C","side":0}}]],[[{"left":{"letter":"A","side":1},"right":{"letter":"B","side":2},"top":{"letter":"C","side":0}},{"left":{"letter":"A","side":1},"right":{"letter":"B","side":2},"top":{"letter":"C","side":0}},{"left":{"letter":"A","side":1},"right":{"letter":"B","side":2},"top":{"letter":"C","side":0}}],[{"left":{"letter":"A","side":1},"right":{"letter":"B","side":2},"top":{"letter":"C","side":0}},{"left":{"letter":"A","side":1},"right":{"letter":"B","side":2},"top":{"letter":"C","side":0}},{"left":{"letter":"A","side":1},"right":{"letter":"B","side":2},"top":{"letter":"C","side":0}}],[{"left":{"letter":"A","side":1},"right":{"letter":"B","side":2},"top":{"letter":"C","side":0}},{"left":{"letter":"A","side":1},"right":{"letter":"B","side":2},"top":{"letter":"C","side":0}},{"left":{"letter":"A","side":1},"right":{"letter":"B","side":2},"top":{"letter":"C","side":0}}]]]}},"moves":[{"playedAt":0,"score":10,"type":{"playedWord":[{"index":{"x":0,"y":0,"z":0},"side":0},{"index":{"x":0,"y":0,"z":0},"side":1},{"index":{"x":0,"y":0,"z":0},"side":2}]}},{"playedAt":0,"score":20,"type":{"removedCube":{"x":1,"y":1,"z":1}}}]}
      """
    let submitRequest = try decoder.decode(
      ServerRoute.Api.Route.Games.SubmitRequest.self,
      from: Data(submitRequestJson.utf8)
    )
    let signature = testHash(Data("\(submitRequestJson)----DEADBEEF----1234567890".utf8))

    var request = URLRequest(
      url: URL(
        string:
          "http://localhost:9876/api/games?accessToken=deadbeef-dead-beef-dead-beefdeadbeef&timestamp=1234567890"
      )!)
    request.httpMethod = "POST"
    request.httpBody = Data(submitRequestJson.utf8)
    request.allHTTPHeaderFields = ["X-Signature": signature.base64EncodedString()]
    let route = testRouter.match(request: request)

    XCTAssertEqual(
      route,
      .api(
        .init(
          accessToken: .init(rawValue: UUID(uuidString: "deadbeef-dead-beef-dead-beefdeadbeef")!),
          isDebug: false,
          route: .games(.submit(submitRequest))
        )
      )
    )

    let dailyChallengeContext = ServerRoute.Api.Route.Games.SubmitRequest.GameContext
      .dailyChallenge(.init(rawValue: .dailyChallengeId))
    XCTAssertEqual(
      dailyChallengeContext,
      try decoder.decode(
        type(of: dailyChallengeContext), from: encoder.encode(dailyChallengeContext))
    )

    let turnBasedContext = ServerRoute.Api.Route.Games.SubmitRequest.GameContext.turnBased(
      .init(
        gameMode: .unlimited,
        language: .en,
        playerIndexToId: [0: .init(rawValue: .deadbeef)],
        puzzle: .mock
      )
    )
    XCTAssertEqual(
      turnBasedContext,
      try decoder.decode(type(of: turnBasedContext), from: encoder.encode(turnBasedContext))
    )
  }

  func testVerifyReceiptMatching() {
    var request = URLRequest(
      url: URL(string: "/api/verify-receipt?accessToken=deadbeef-dead-beef-dead-beefdeadbeef")!
    )
    request.httpMethod = "POST"
    request.httpBody = Data()

    let route = testRouter.match(request: request)

    XCTAssertEqual(
      route,
      .api(
        .init(
          accessToken: .init(rawValue: UUID(uuidString: "deadbeef-dead-beef-dead-beefdeadbeef")!),
          isDebug: false,
          route: .verifyReceipt(Data())
        )
      )
    )
  }

  func testSubmitSharedGame() throws {
    let completedGame = CompletedGame(
      cubes: update(.mock) {
        $0.first.first.first = .init(
          left: .init(letter: "A", side: .left),
          right: .init(letter: "B", side: .right),
          top: .init(letter: "C", side: .top)
        )
      },
      gameContext: .dailyChallenge(.init(rawValue: .deadbeef)),
      gameMode: .timed,
      gameStartTime: .mock,
      language: .en,
      moves: [
        .init(
          playedAt: .mock,
          playerIndex: nil,
          reactions: nil,
          score: 0,
          type: .removedCube(.zero)
        ),
        .init(
          playedAt: .mock,
          playerIndex: nil,
          reactions: nil,
          score: 10,
          type: .playedWord([
            .init(index: .init(x: .zero, y: .zero, z: .one), side: .left),
            .init(index: .init(x: .zero, y: .zero, z: .one), side: .right),
            .init(index: .init(x: .zero, y: .zero, z: .one), side: .top),
          ])
        ),
      ],
      secondsPlayed: 0
    )

    var request = URLRequest(
      url: URL(string: "/api/sharedGames?accessToken=deadbeef-dead-beef-dead-beefdeadbeef")!
    )
    request.httpMethod = "POST"
    request.httpBody = try JSONEncoder().encode(completedGame)

    let route = testRouter.match(request: request)

    XCTAssertEqual(
      route,
      .api(
        .init(
          accessToken: .init(rawValue: UUID(uuidString: "deadbeef-dead-beef-dead-beefdeadbeef")!),
          isDebug: false,
          route: .sharedGame(.share(completedGame))
        )
      )
    )
  }

  func testShowSharedGame() {
    XCTAssertEqual(
      testRouter.match(request: URLRequest(url: URL(string: "isowords:///sharedGames/deadbeef")!)),
      .sharedGame(.show("deadbeef"))
    )
  }

  func testFetchVocabLeaderboard() {
    XCTAssertEqual(
      testRouter.match(
        string: """
          /api/leaderboard-scores/vocab?\
          language=en&\
          timeScope=allTime&\
          accessToken=deadbeef-dead-beef-dead-beefdeadbeef
          """
      ),
      .api(
        .init(
          accessToken: .init(rawValue: .deadbeef),
          isDebug: false,
          route: .leaderboard(.vocab(.fetch(language: .en, timeScope: .allTime)))
        )
      )
    )
  }

  func testFetchVocabWord() {
    XCTAssertEqual(
      testRouter.match(
        string: """
          /api/leaderboard-scores/vocab/words/\
          deadbeef-dead-beef-dead-beefdead304d?\
          accessToken=deadbeef-dead-beef-dead-beefdeadbeef
          """
      ),
      .api(
        .init(
          accessToken: .init(rawValue: .deadbeef),
          isDebug: false,
          route: .leaderboard(
            .vocab(
              .fetchWord(
                wordId: .init(
                  rawValue: UUID(uuidString: "deadbeef-dead-beef-dead-beefdead304d")!
                )
              )
            )
          )
        )
      )
    )
  }

  func testStartDailyChallenges() {
    var request = URLRequest(
      url: URL(
        string: """
          /api/daily-challenges?accessToken=deadbeef-dead-beef-dead-beefdeadbeef&\
          gameMode=unlimited&\
          language=en
          """
      )!
    )
    request.httpMethod = "POST"
    XCTAssertEqual(
      testRouter.match(request: request),
      .api(
        .init(
          accessToken: .init(rawValue: .deadbeef),
          isDebug: false,
          route: .dailyChallenge(.start(gameMode: .unlimited, language: .en))
        )
      )
    )
  }

  func testTodayDailyChallenges() {
    XCTAssertEqual(
      testRouter.match(
        string: """
          /api/daily-challenges/today?accessToken=deadbeef-dead-beef-dead-beefdeadbeef&\
          language=en
          """
      ),
      .api(
        .init(
          accessToken: .init(rawValue: .deadbeef),
          isDebug: false,
          route: .dailyChallenge(.today(language: .en))
        )
      )
    )
  }

  func testDailyChallengesResults() {
    XCTAssertEqual(
      testRouter.match(
        string: """
          /api/daily-challenges/results?accessToken=deadbeef-dead-beef-dead-beefdeadbeef&\
          gameMode=unlimited&\
          game-number=42&\
          language=en
          """
      ),
      .api(
        .init(
          accessToken: .init(rawValue: .deadbeef),
          isDebug: false,
          route: .dailyChallenge(
            .results(
              .fetch(
                gameMode: .unlimited,
                gameNumber: 42,
                language: .en
              )
            )
          )
        )
      )
    )
  }

  func testDailyChallengesHistory() {
    XCTAssertEqual(
      testRouter.match(
        string: """
          /api/daily-challenges/results/history?accessToken=deadbeef-dead-beef-dead-beefdeadbeef&\
          gameMode=unlimited&\
          language=en
          """
      ),
      .api(
        .init(
          accessToken: .init(rawValue: .deadbeef),
          isDebug: false,
          route: .dailyChallenge(
            .results(
              .history(gameMode: .unlimited, language: .en)
            )
          )
        )
      )
    )
  }

  func testRegisterPushNotification() throws {
    var request = URLRequest(
      url: URL(string: "/api/push-tokens?accessToken=DEADBEEF-DEAD-BEEF-DEAD-BEEFDEADBEEF")!
    )
    request.httpMethod = "POST"
    request.httpBody = Data(
      #"""
      {"token": "deadbeef"}
      """#.utf8
    )

    let route = testRouter.match(request: request)

    XCTAssertEqual(
      route,
      .api(
        .init(
          accessToken: .init(rawValue: .deadbeef),
          isDebug: false,
          route: .push(
            .register(
              .init(authorizationStatus: .provisional, build: 0, token: "deadbeef")
            )
          )
        )
      )
    )
  }

  func testRegisterPushNotification_WithBuild() throws {
    var request = URLRequest(
      url: URL(string: "/api/push-tokens?accessToken=deadbeef-dead-beef-dead-beefdeadbeef")!
    )
    request.httpMethod = "POST"
    request.httpBody = Data(
      #"""
      {"build": 42, "token": "deadbeef"}
      """#.utf8
    )

    let route = testRouter.match(request: request)

    XCTAssertEqual(
      route,
      .api(
        .init(
          accessToken: .init(rawValue: .deadbeef),
          isDebug: false,
          route: .push(
            .register(
              .init(authorizationStatus: .provisional, build: 42, token: "deadbeef")
            )
          )
        )
      )
    )
  }

  func testRegisterPushNotification_WithBuildAndAuthorizationStatus() throws {
    var request = URLRequest(
      url: URL(string: "/api/push-tokens?accessToken=deadbeef-dead-beef-dead-beefdeadbeef")!
    )
    request.httpMethod = "POST"
    request.httpBody = Data(
      #"""
      {"build": 42, "token": "deadbeef", "authorizationStatus": 2}
      """#.utf8
    )

    let route = testRouter.match(request: request)

    XCTAssertEqual(
      route,
      .api(
        .init(
          accessToken: .init(rawValue: .deadbeef),
          isDebug: false,
          route: .push(
            .register(
              .init(authorizationStatus: .authorized, build: 42, token: "deadbeef")
            )
          )
        )
      )
    )
  }
}
