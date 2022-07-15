import ComposableArchitecture
import SharedModels

public struct LocalDatabaseClient {
  @available(*, deprecated) public var fetchGamesForWord: (String) -> Effect<[LocalDatabaseClient.Game], Error>
  public var fetchGamesForWordAsync: @Sendable (String) async throws -> [LocalDatabaseClient.Game]
  @available(*, deprecated) public var fetchStats: Effect<Stats, Error>
  public var fetchStatsAsync: @Sendable () async throws -> Stats
  @available(*, deprecated) public var fetchVocab: Effect<Vocab, Error>
  public var fetchVocabAsync: @Sendable () async throws -> Vocab
  @available(*, deprecated) public var migrate: Effect<Void, Error>
  public var migrateAsync: @Sendable () async throws -> Void
  @available(*, deprecated) public var playedGamesCount: (GameContext) -> Effect<Int, Error>
  public var playedGamesCountAsync: @Sendable (GameContext) async throws -> Int
  @available(*, deprecated) public var saveGame: (CompletedGame) -> Effect<Void, Error>
  public var saveGameAsync: @Sendable (CompletedGame) async throws -> Void

  public struct Game: Equatable {
    public var id: Int
    public var completedGame: CompletedGame
    public var gameMode: GameMode
    public var secondsPlayed: Int
    public var startedAt: Date
  }

  public struct Stats: Equatable {
    public var averageWordLength: Double?
    public var gamesPlayed = 0
    public var highestScoringWord: Word?
    public var highScoreTimed: Int?
    public var highScoreUnlimited: Int?
    public var longestWord: String?
    public var secondsPlayed = 0
    public var wordsFound = 0

    public struct Word: Equatable {
      public var letters: String
      public var score: Int
    }
  }

  public struct Vocab: Equatable {
    public var words: [Word]

    public struct Word: Equatable {
      public var letters: String
      public var playCount: Int
      public var score: Int
    }
  }

  public enum GameContext: String, Codable {
    case dailyChallenge
    case shared
    case solo
    case turnBased

    public init(gameContext: CompletedGame.GameContext) {
      switch gameContext {
      case .dailyChallenge:
        self = .dailyChallenge
      case .shared:
        self = .shared
      case .solo:
        self = .solo
      case .turnBased:
        self = .turnBased
      }
    }
  }
}

extension LocalDatabaseClient {
  public static let noop = Self(
    fetchGamesForWord: { _ in .none },
    fetchGamesForWordAsync: { _ in try await Task.never() },
    fetchStats: .none,
    fetchStatsAsync: { try await Task.never() },
    fetchVocab: .none,
    fetchVocabAsync: { try await Task.never() },
    migrate: .none,
    migrateAsync: {},
    playedGamesCount: { _ in .none },
    playedGamesCountAsync: { _ in try await Task.never() },
    saveGame: { _ in .none },
    saveGameAsync: { _ in try await Task.never() }
  )
}
