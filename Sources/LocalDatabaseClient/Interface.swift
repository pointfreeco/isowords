import ComposableArchitecture
import Foundation
import SharedModels

extension DependencyValues {
  public var database: LocalDatabaseClient {
    get { self[LocalDatabaseClientKey.self] }
    set { self[LocalDatabaseClientKey.self] = newValue }
  }

  private enum LocalDatabaseClientKey: TestDependencyKey {
    static let testValue = LocalDatabaseClient.unimplemented
  }
}

public struct LocalDatabaseClient {
  public var fetchGamesForWord: @Sendable (String) async throws -> [LocalDatabaseClient.Game]
  public var fetchStats: @Sendable () async throws -> Stats
  public var fetchVocab: @Sendable () async throws -> Vocab
  public var migrate: @Sendable () async throws -> Void
  public var playedGamesCount: @Sendable (GameContext) async throws -> Int
  public var saveGame: @Sendable (CompletedGame) async throws -> Void

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
    fetchGamesForWord: { _ in try await Task.never() },
    fetchStats: { try await Task.never() },
    fetchVocab: { try await Task.never() },
    migrate: {},
    playedGamesCount: { _ in try await Task.never() },
    saveGame: { _ in try await Task.never() }
  )
}
