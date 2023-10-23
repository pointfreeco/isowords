import Build
import CasePaths
import Foundation
import Tagged

public enum ServerRoute: Equatable {
  case api(Api)
  case appSiteAssociation
  case appStore
  case authenticate(AuthenticateRequest)
  case demo(Demo)
  case download
  case home
  case pressKit
  case privacyPolicy
  case sharedGame(SharedGame)

  public enum Demo: Equatable {
    case submitGame(SubmitRequest)

    public struct SubmitRequest: Codable, Equatable {
      public let gameMode: GameMode
      public let score: Int

      public init(
        gameMode: GameMode,
        score: Int
      ) {
        self.gameMode = gameMode
        self.score = score
      }
    }
  }

  public struct Api: Equatable {
    public let accessToken: AccessToken
    public let isDebug: Bool
    public let route: Route

    public init(
      accessToken: AccessToken,
      isDebug: Bool,
      route: Route
    ) {
      self.accessToken = accessToken
      self.isDebug = isDebug
      self.route = route
    }

    @CasePathable
    public enum Route: Equatable, Sendable {
      case changelog(build: Build.Number)
      case config(build: Build.Number)
      case currentPlayer
      case dailyChallenge(DailyChallenge)
      case games(Games)
      case leaderboard(Leaderboard)
      case push(Push)
      case sharedGame(SharedGame)
      case verifyReceipt(Data)

      public enum DailyChallenge: Equatable, Sendable {
        case results(Results)
        case start(gameMode: GameMode, language: Language)
        case today(language: Language)

        public enum Results: Equatable, Sendable {
          case fetch(
            gameMode: GameMode, gameNumber: SharedModels.DailyChallenge.GameNumber?,
            language: Language)
          case history(gameMode: GameMode, language: Language)
        }
      }

      @CasePathable
      public enum Games: Equatable, Sendable {
        case submit(SubmitRequest)

        public struct SubmitRequest: Codable, Equatable, Sendable {
          public let gameContext: GameContext
          public let moves: Moves

          public init(
            gameContext: GameContext,
            moves: Moves
          ) {
            self.gameContext = gameContext
            self.moves = moves
          }

          public enum GameContext: Codable, Equatable, Sendable {
            case dailyChallenge(SharedModels.DailyChallenge.Id)
            case shared(SharedModels.SharedGame.Code)
            case solo(Solo)
            case turnBased(TurnBased)

            public struct Solo: Codable, Equatable, Sendable {
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

            public struct TurnBased: Codable, Equatable, Sendable {
              public let gameMode: GameMode
              public let language: Language
              public let playerIndexToId: [Move.PlayerIndex: Player.Id]
              public let puzzle: ArchivablePuzzle

              public init(
                gameMode: GameMode,
                language: Language,
                playerIndexToId: [Move.PlayerIndex: Player.Id],
                puzzle: ArchivablePuzzle
              ) {
                self.gameMode = gameMode
                self.language = language
                self.playerIndexToId = playerIndexToId
                self.puzzle = puzzle
              }
            }
          }
        }
      }

      public enum Leaderboard: Equatable, Sendable {
        case fetch(gameMode: GameMode, language: Language, timeScope: TimeScope)
        case vocab(Vocab)
        case weekInReview(language: Language)

        public enum Vocab: Equatable, Sendable {
          case fetch(language: Language, timeScope: TimeScope)
          case fetchWord(wordId: Word.Id)
        }
      }

      public enum Push: Equatable, Sendable {
        case register(Register)
        case updateSetting(Setting)

        public struct Register: Codable, Equatable, Sendable {
          public let authorizationStatus: PushAuthorizationStatus
          public let build: Build.Number
          public let token: String

          public init(
            authorizationStatus: PushAuthorizationStatus,
            build: Build.Number,
            token: String
          ) {
            self.authorizationStatus = authorizationStatus
            self.build = build
            self.token = token
          }

          public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.authorizationStatus =
              (try? container.decode(PushAuthorizationStatus.self, forKey: .authorizationStatus))
              ?? .provisional
            self.build = (try? container.decode(Build.Number.self, forKey: .build)) ?? 0
            self.token = try container.decode(String.self, forKey: .token)
          }
        }

        public struct Setting: Codable, Equatable, Sendable {
          public let notificationType: PushNotificationContent.CodingKeys
          public let sendNotifications: Bool

          public init(
            notificationType: PushNotificationContent.CodingKeys,
            sendNotifications: Bool
          ) {
            self.notificationType = notificationType
            self.sendNotifications = sendNotifications
          }
        }
      }

      public enum SharedGame: Equatable, Sendable {
        case fetch(SharedModels.SharedGame.Code)
        case share(CompletedGame)
      }
    }
  }

  public struct AuthenticateRequest: Codable, Equatable {
    public let deviceId: DeviceId
    public let displayName: String?
    public let gameCenterLocalPlayerId: GameCenterLocalPlayerId?
    public let timeZone: String

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
  }

  public enum SharedGame: Equatable {
    case show(SharedModels.SharedGame.Code)
  }
}

extension ServerRoute.AuthenticateRequest {
  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.deviceId = try container.decode(DeviceId.self, forKey: .deviceId)
    self.displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
    self.gameCenterLocalPlayerId = try container.decodeIfPresent(
      GameCenterLocalPlayerId.self, forKey: .gameCenterLocalPlayerId)
    self.timeZone = (try? container.decode(String.self, forKey: .timeZone)) ?? "America/New_York"
  }
}
