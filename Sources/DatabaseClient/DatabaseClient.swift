import Either
import Foundation
import SharedModels
import SnsClient

public struct DatabaseClient {
  public var completeDailyChallenge:
    (DailyChallenge.Id, Player.Id) -> EitherIO<Error, DailyChallengePlay>
  public var createTodaysDailyChallenge:
    (CreateTodaysDailyChallengeRequest) -> EitherIO<Error, DailyChallenge>
  public var fetchActiveDailyChallengeArns: () -> EitherIO<Error, [DailyChallengeArn]>
  public var fetchAppleReceipt: (Player.Id) -> EitherIO<Error, AppleReceipt?>
  public var fetchDailyChallengeById: (DailyChallenge.Id) -> EitherIO<Error, DailyChallenge>
  public var fetchDailyChallengeHistory:
    (DailyChallengeHistoryRequest) -> EitherIO<Error, [DailyChallengeHistoryResponse.Result]>
  public var fetchDailyChallengeReport:
    (DailyChallengeReportRequest) -> EitherIO<Error, [DailyChallengeReportResult]>
  public var fetchDailyChallengeResult:
    (DailyChallengeRankRequest) -> EitherIO<Error, DailyChallengeResult>
  public var fetchDailyChallengeResults:
    (DailyChallengeResultsRequest) -> EitherIO<Error, [FetchDailyChallengeResultsResponse.Result]>
  public var fetchLeaderboardSummary:
    (FetchLeaderboardSummaryRequest) -> EitherIO<Error, LeaderboardScoreResult.Rank>
  public var fetchLeaderboardWeeklyRanks:
    (Language, Player) -> EitherIO<Error, [FetchWeekInReviewResponse.Rank]>
  public var fetchLeaderboardWeeklyWord:
    (Language, Player) -> EitherIO<Error, FetchWeekInReviewResponse.Word?>
  public var fetchPlayerByAccessToken: (AccessToken) -> EitherIO<Error, Player?>
  public var fetchPlayerByDeviceId: (DeviceId) -> EitherIO<Error, Player?>
  public var fetchPlayerByGameCenterLocalPlayerId:
    (GameCenterLocalPlayerId) -> EitherIO<Error, Player?>
  public var fetchRankedLeaderboardScores:
    (FetchLeaderboardRequest) -> EitherIO<Error, [FetchLeaderboardResponse.Entry]>
  public var fetchSharedGame: (SharedGame.Code) -> EitherIO<Error, SharedGame>
  public var fetchTodaysDailyChallenges: (Language) -> EitherIO<Error, [DailyChallenge]>
  public var fetchVocabLeaderboard:
    (Language, Player, TimeScope, VocabSort) -> EitherIO<
      Error, [FetchVocabLeaderboardResponse.Entry]
    >
  public var fetchVocabLeaderboardWord: (Word.Id) -> EitherIO<Error, FetchVocabWordResponse>
  public var insertPlayer: (InsertPlayerRequest) -> EitherIO<Error, Player>
  public var insertPushToken: (InsertPushTokenRequest) -> EitherIO<Error, Void>
  public var insertSharedGame: (CompletedGame, Player) -> EitherIO<Error, SharedGame>
  public var migrate: () -> EitherIO<Error, Void>
  public var shutdown: () -> EitherIO<Error, Void>
  public var startDailyChallenge:
    (DailyChallenge.Id, Player.Id) -> EitherIO<Error, DailyChallengePlay>
  public var submitLeaderboardScore: (SubmitLeaderboardScore) -> EitherIO<Error, LeaderboardScore>
  public var updateAppleReceipt: (Player.Id, AppleVerifyReceiptResponse) -> EitherIO<Error, Void>
  public var updatePlayer: (UpdatePlayerRequest) -> EitherIO<Error, Player>
  public var updatePushSetting:
    (Player.Id, PushNotificationContent.CodingKeys, Bool) -> EitherIO<Error, Void>

  public init(
    completeDailyChallenge: @escaping (DailyChallenge.Id, Player.Id) -> EitherIO<
      Error, DailyChallengePlay
    >,
    createTodaysDailyChallenge: @escaping (CreateTodaysDailyChallengeRequest) -> EitherIO<
      Error, DailyChallenge
    >,
    fetchActiveDailyChallengeArns: @escaping () -> EitherIO<Error, [DailyChallengeArn]>,
    fetchAppleReceipt: @escaping (Player.Id) -> EitherIO<Error, AppleReceipt?>,
    fetchDailyChallengeById: @escaping (DailyChallenge.Id) -> EitherIO<Error, DailyChallenge>,
    fetchDailyChallengeHistory: @escaping (DailyChallengeHistoryRequest) -> EitherIO<
      Error, [DailyChallengeHistoryResponse.Result]
    >,
    fetchDailyChallengeReport: @escaping (DailyChallengeReportRequest) -> EitherIO<
      Error, [DailyChallengeReportResult]
    >,
    fetchDailyChallengeResult: @escaping (DailyChallengeRankRequest) -> EitherIO<
      Error, DailyChallengeResult
    >,
    fetchDailyChallengeResults: @escaping (DailyChallengeResultsRequest) -> EitherIO<
      Error, [FetchDailyChallengeResultsResponse.Result]
    >,
    fetchLeaderboardSummary: @escaping (FetchLeaderboardSummaryRequest) -> EitherIO<
      Error, LeaderboardScoreResult.Rank
    >,
    fetchLeaderboardWeeklyRanks: @escaping (Language, Player) -> EitherIO<
      Error, [FetchWeekInReviewResponse.Rank]
    >,
    fetchLeaderboardWeeklyWord: @escaping (Language, Player) -> EitherIO<
      Error, FetchWeekInReviewResponse.Word?
    >,
    fetchPlayerByAccessToken: @escaping (AccessToken) -> EitherIO<Error, Player?>,
    fetchPlayerByDeviceId: @escaping (DeviceId) -> EitherIO<Error, Player?>,
    fetchPlayerByGameCenterLocalPlayerId: @escaping (GameCenterLocalPlayerId) -> EitherIO<
      Error, Player?
    >,
    fetchRankedLeaderboardScores: @escaping (FetchLeaderboardRequest) -> EitherIO<
      Error, [FetchLeaderboardResponse.Entry]
    >,
    fetchSharedGame: @escaping (SharedGame.Code) -> EitherIO<Error, SharedGame>,
    fetchTodaysDailyChallenges: @escaping (Language) -> EitherIO<Error, [DailyChallenge]>,
    fetchVocabLeaderboard: @escaping (Language, Player, TimeScope, VocabSort) -> EitherIO<
      Error, [FetchVocabLeaderboardResponse.Entry]
    >,
    fetchVocabLeaderboardWord: @escaping (Word.Id) -> EitherIO<Error, FetchVocabWordResponse>,
    insertPlayer: @escaping (InsertPlayerRequest) -> EitherIO<Error, Player>,
    insertPushToken: @escaping (InsertPushTokenRequest) -> EitherIO<Error, Void>,
    insertSharedGame: @escaping (CompletedGame, Player) -> EitherIO<Error, SharedGame>,
    migrate: @escaping () -> EitherIO<Error, Void>,
    shutdown: @escaping () -> EitherIO<Error, Void>,
    startDailyChallenge: @escaping (DailyChallenge.Id, Player.Id) -> EitherIO<
      Error, DailyChallengePlay
    >,
    submitLeaderboardScore: @escaping (SubmitLeaderboardScore) -> EitherIO<Error, LeaderboardScore>,
    updateAppleReceipt: @escaping (Player.Id, AppleVerifyReceiptResponse) -> EitherIO<Error, Void>,
    updatePlayer: @escaping (UpdatePlayerRequest) -> EitherIO<Error, Player>,
    updatePushSetting: @escaping (Player.Id, PushNotificationContent.CodingKeys, Bool) -> EitherIO<
      Error, Void
    >
  ) {
    self.completeDailyChallenge = completeDailyChallenge
    self.createTodaysDailyChallenge = createTodaysDailyChallenge
    self.fetchActiveDailyChallengeArns = fetchActiveDailyChallengeArns
    self.fetchAppleReceipt = fetchAppleReceipt
    self.fetchDailyChallengeById = fetchDailyChallengeById
    self.fetchDailyChallengeHistory = fetchDailyChallengeHistory
    self.fetchDailyChallengeReport = fetchDailyChallengeReport
    self.fetchDailyChallengeResult = fetchDailyChallengeResult
    self.fetchDailyChallengeResults = fetchDailyChallengeResults
    self.fetchLeaderboardSummary = fetchLeaderboardSummary
    self.fetchLeaderboardWeeklyRanks = fetchLeaderboardWeeklyRanks
    self.fetchLeaderboardWeeklyWord = fetchLeaderboardWeeklyWord
    self.fetchPlayerByAccessToken = fetchPlayerByAccessToken
    self.fetchPlayerByDeviceId = fetchPlayerByDeviceId
    self.fetchPlayerByGameCenterLocalPlayerId = fetchPlayerByGameCenterLocalPlayerId
    self.fetchRankedLeaderboardScores = fetchRankedLeaderboardScores
    self.fetchSharedGame = fetchSharedGame
    self.fetchTodaysDailyChallenges = fetchTodaysDailyChallenges
    self.fetchVocabLeaderboard = fetchVocabLeaderboard
    self.fetchVocabLeaderboardWord = fetchVocabLeaderboardWord
    self.insertPlayer = insertPlayer
    self.insertPushToken = insertPushToken
    self.insertSharedGame = insertSharedGame
    self.migrate = migrate
    self.shutdown = shutdown
    self.startDailyChallenge = startDailyChallenge
    self.submitLeaderboardScore = submitLeaderboardScore
    self.updateAppleReceipt = updateAppleReceipt
    self.updatePlayer = updatePlayer
    self.updatePushSetting = updatePushSetting
  }

  public struct DailyChallengeReportResult: Codable, Equatable {
    public let arn: EndpointArn
    public let gameMode: GameMode
    public let outOf: Int
    public let rank: Int?
    public let score: Int?
  }

  public struct DailyChallengeArn: Codable, Equatable {
    public var arn: EndpointArn
    public var endsAt: Date

    public init(
      arn: EndpointArn,
      endsAt: Date
    ) {
      self.arn = arn
      self.endsAt = endsAt
    }
  }

  public struct _DailyChallengeResultsRequest {
    public let gameMode: GameMode
    public let language: Language
    public let playerId: Player.Id

    public init(
      gameMode: GameMode,
      language: Language,
      playerId: Player.Id
    ) {
      self.gameMode = gameMode
      self.language = language
      self.playerId = playerId
    }
  }

  public struct DailyChallengeResultsRequest {
    public let gameMode: GameMode
    public let gameNumber: DailyChallenge.GameNumber?
    public let language: Language
    public let playerId: Player.Id

    public init(
      gameMode: GameMode,
      gameNumber: DailyChallenge.GameNumber?,
      language: Language,
      playerId: Player.Id
    ) {
      self.gameMode = gameMode
      self.gameNumber = gameNumber
      self.language = language
      self.playerId = playerId
    }
  }

  public struct DailyChallengeHistoryRequest {
    public let gameMode: GameMode
    public let language: Language
    public let playerId: Player.Id

    public init(
      gameMode: GameMode,
      language: Language,
      playerId: Player.Id
    ) {
      self.gameMode = gameMode
      self.language = language
      self.playerId = playerId
    }
  }

  public struct DailyChallengeReportRequest {
    public let gameMode: GameMode
    public let language: Language

    public init(
      gameMode: GameMode,
      language: Language
    ) {
      self.gameMode = gameMode
      self.language = language
    }
  }

  public struct FetchLeaderboardSummaryRequest {
    public let gameMode: GameMode
    public let timeScope: TimeScope
    public let type: SummaryType

    public enum SummaryType {
      case player(scoreId: LeaderboardScore.Id, playerId: Player.Id)
      case anonymous(score: Int)
    }

    public init(
      gameMode: GameMode,
      timeScope: TimeScope,
      type: SummaryType
    ) {
      self.gameMode = gameMode
      self.timeScope = timeScope
      self.type = type
    }
  }

  public struct FetchLeaderboardRequest {
    public let gameMode: GameMode
    public let language: Language
    public let playerId: Player.Id
    public let timeScope: TimeScope

    public init(
      gameMode: GameMode,
      language: Language,
      playerId: Player.Id,
      timeScope: TimeScope
    ) {
      self.gameMode = gameMode
      self.language = language
      self.playerId = playerId
      self.timeScope = timeScope
    }
  }

  public struct CreateTodaysDailyChallengeRequest {
    public let gameMode: GameMode
    public let language: Language
    public let puzzle: ArchivablePuzzle

    public init(
      gameMode: GameMode,
      language: Language,
      puzzle: ArchivablePuzzle
    ) {
      self.gameMode = gameMode
      self.language = language
      self.puzzle = puzzle
    }
  }

  public struct InsertPlayerRequest: Equatable {
    public var deviceId: DeviceId
    public var displayName: String?
    public var gameCenterLocalPlayerId: GameCenterLocalPlayerId?
    public var timeZone: String

    public init(
      deviceId: DeviceId,
      displayName: String?,
      gameCenterLocalPlayerId: GameCenterLocalPlayerId?,
      timeZone: String
    ) {
      self.deviceId = deviceId
      self.displayName = displayName
      self.gameCenterLocalPlayerId = gameCenterLocalPlayerId
      self.timeZone = timeZone
    }

    #if DEBUG
      public static let blob = Self(
        deviceId: .init(rawValue: UUID(uuidString: "deadbeef-dead-beef-dead-beefdeadbeef")!),
        displayName: "Blob",
        gameCenterLocalPlayerId: "_id:blob",
        timeZone: "America/New_York"
      )

      public static let blobJr = Self(
        deviceId: .init(rawValue: UUID(uuidString: "cafebeef-dead-beef-dead-beefdeadbeef")!),
        displayName: "Blob Jr",
        gameCenterLocalPlayerId: "_id:blob_jr",
        timeZone: "America/New_York"
      )

      public static let blobSr = Self(
        deviceId: .init(rawValue: UUID(uuidString: "beefbeef-dead-beef-dead-beefdeadbeef")!),
        displayName: "Blob Sr",
        gameCenterLocalPlayerId: "_id:blob_sr",
        timeZone: "America/New_York"
      )
    #endif
  }

  public struct InsertPushTokenRequest: Equatable {
    public let arn: String
    public let authorizationStatus: PushAuthorizationStatus
    public let build: Int
    public let player: Player
    public let token: String

    public init(
      arn: String,
      authorizationStatus: PushAuthorizationStatus,
      build: Int,
      player: Player,
      token: String
    ) {
      self.arn = arn
      self.authorizationStatus = authorizationStatus
      self.build = build
      self.player = player
      self.token = token
    }
  }

  public struct LeaderboardWeeklyRank: Codable, Equatable {
    public let gameMode: GameMode
    public let outOf: Int
    public let rank: Int
  }

  public struct LeaderboardWeeklyWord: Codable, Equatable {
    public let letters: String
    public let score: Int
  }

  public struct SubmitLeaderboardScore: Equatable {
    public let dailyChallengeId: DailyChallenge.Id?
    public let gameContext: GameContext
    public let gameMode: GameMode
    public let language: Language
    public let moves: Moves
    public let playerId: Player.Id
    public let puzzle: ArchivablePuzzle
    public let score: Int
    public let words: [SubmitLeaderboardWord]

    public init(
      dailyChallengeId: DailyChallenge.Id?,
      gameContext: GameContext,
      gameMode: GameMode,
      language: Language,
      moves: Moves,
      playerId: Player.Id,
      puzzle: ArchivablePuzzle,
      score: Int,
      words: [SubmitLeaderboardWord]
    ) {
      self.dailyChallengeId = dailyChallengeId
      self.gameContext = gameContext
      self.gameMode = gameMode
      self.language = language
      self.moves = moves
      self.playerId = playerId
      self.puzzle = puzzle
      self.score = score
      self.words = words
    }

    public enum GameContext: String, Codable, Equatable {
      case dailyChallenge
      case solo
      case turnBased
    }
  }

  public struct SubmitLeaderboardWord: Equatable {
    public let moveIndex: Int
    public let score: Int
    public let word: String

    public init(
      moveIndex: Int,
      score: Int,
      word: String
    ) {
      self.moveIndex = moveIndex
      self.score = score
      self.word = word
    }
  }

  public struct DailyChallengeRankRequest: Equatable {
    public let dailyChallengeId: DailyChallenge.Id
    public let playerId: Player.Id

    public init(
      dailyChallengeId: DailyChallenge.Id,
      playerId: Player.Id
    ) {
      self.dailyChallengeId = dailyChallengeId
      self.playerId = playerId
    }
  }

  public struct UpdatePlayerRequest {
    public let displayName: String?
    public let gameCenterLocalPlayerId: GameCenterLocalPlayerId?
    public let playerId: Player.Id
    public let timeZone: String

    public init(
      displayName: String?,
      gameCenterLocalPlayerId: GameCenterLocalPlayerId?,
      playerId: Player.Id,
      timeZone: String
    ) {
      self.displayName = displayName
      self.gameCenterLocalPlayerId = gameCenterLocalPlayerId
      self.playerId = playerId
      self.timeZone = timeZone
    }
  }
}
