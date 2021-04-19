import DatabaseClient
import DictionaryClient
import Either
import Foundation
import HttpPipeline
import Prelude
import ServerRouter
import SharedModels

public struct SubmitGameRequest {
  public let currentPlayer: Player
  public let database: DatabaseClient
  public let dictionary: DictionaryClient
  public let submitRequest: ServerRoute.Api.Route.Games.SubmitRequest

  public init(
    currentPlayer: Player,
    database: DatabaseClient,
    dictionary: DictionaryClient,
    submitRequest: ServerRoute.Api.Route.Games.SubmitRequest
  ) {
    self.currentPlayer = currentPlayer
    self.database = database
    self.dictionary = dictionary
    self.submitRequest = submitRequest
  }
}

public func submitGameMiddleware(
  _ conn: Conn<StatusLineOpen, SubmitGameRequest>
) -> IO<Conn<HeadersOpen, Either<ApiError, SubmitGameResponse>>> {

  let request = conn.data

  struct UnverifiedArchiveData {
    let dailyChallengeId: DailyChallenge.Id?
    let gameContext: DatabaseClient.SubmitLeaderboardScore.GameContext
    let gameMode: GameMode
    let language: Language
    let playerId: Player.Id
    let puzzle: ArchivablePuzzle
    let wordIndices: [Int]
  }

  let unverifiedArchiveData: EitherIO<Error, [UnverifiedArchiveData]>
  switch request.submitRequest.gameContext {
  case let .dailyChallenge(dailyChallengeId):
    unverifiedArchiveData = request.database.fetchDailyChallengeById(dailyChallengeId).map {
      [
        UnverifiedArchiveData(
          dailyChallengeId: dailyChallengeId,
          gameContext: .dailyChallenge,
          gameMode: $0.gameMode,
          language: $0.language,
          playerId: request.currentPlayer.id,
          puzzle: $0.puzzle,
          wordIndices: Array(request.submitRequest.moves.indices)
        )
      ]
    }

  case .shared:
    unverifiedArchiveData = pure([])

  case let .solo(solo):
    unverifiedArchiveData = pure([
      UnverifiedArchiveData(
        dailyChallengeId: nil,
        gameContext: .solo,
        gameMode: solo.gameMode,
        language: solo.language,
        playerId: request.currentPlayer.id,
        puzzle: solo.puzzle,
        wordIndices: Array(request.submitRequest.moves.indices)
      )
    ])

  case let .turnBased(turnBased):
    unverifiedArchiveData = pure(
      turnBased.playerIndexToId.map { playerIndex, playerId in
        UnverifiedArchiveData(
          dailyChallengeId: nil,
          gameContext: .turnBased,
          gameMode: turnBased.gameMode,
          language: turnBased.language,
          playerId: playerId,
          puzzle: turnBased.puzzle,
          wordIndices: request.submitRequest.moves
            .enumerated()
            .filter { $0.element.playerIndex == playerIndex }
            .map(\.offset)
        )
      }
    )
  }

  let leaderboardScore: EitherIO<Error, LeaderboardScore?> =
    unverifiedArchiveData
    .flatMap { archiveData in
      EitherIO(
        run: sequence(
          archiveData.map { archiveDatum -> Parallel<Either<Error, LeaderboardScore>> in
            guard
              let verifiedResult = verify(
                moves: request.submitRequest.moves,
                playedOn: archiveDatum.puzzle,
                isValidWord: { request.dictionary.contains($0, archiveDatum.language) }
              )
            else { return pure(.left(ApiError(error: VerificationFailed()))) }

            return request.database.submitLeaderboardScore(
              .init(
                dailyChallengeId: archiveDatum.dailyChallengeId,
                gameContext: archiveDatum.gameContext,
                gameMode: archiveDatum.gameMode,
                language: archiveDatum.language,
                moves: request.submitRequest.moves,
                playerId: archiveDatum.playerId,
                puzzle: archiveDatum.puzzle,
                score: archiveDatum.wordIndices.reduce(into: 0) { score, index in
                  score += request.submitRequest.moves[index].score
                },
                words: archiveDatum.wordIndices.compactMap { idx in
                  let verifiedMove = verifiedResult.verifiedMoves[idx]
                  return verifiedMove.foundWord.map { foundWord in
                    .init(moveIndex: idx, score: verifiedMove.score, word: foundWord)
                  }
                }
              )
            )
            .run
            .parallel
          }
        )
        .map(sequence)
        .sequential
      )
      .map { leaderboardScores in
        leaderboardScores.first(where: { $0.playerId == request.currentPlayer.id })
      }
    }

  return
    leaderboardScore
    .flatMap { leaderboardScore -> EitherIO<Error, SubmitGameResponse> in
      switch request.submitRequest.gameContext {
      case let .dailyChallenge(dailyChallengeId):
        return request.database.completeDailyChallenge(dailyChallengeId, request.currentPlayer.id)
          .flatMap { _ in
            request.database.fetchDailyChallengeResult(
              .init(
                dailyChallengeId: dailyChallengeId,
                playerId: request.currentPlayer.id
              )
            )
            .map {
              SubmitGameResponse(
                context: .dailyChallenge($0),
                message: praise(rank: $0.rank ?? 0, outOf: $0.outOf)
              )
            }
          }

      case let .shared(code):
        return request.database
          .fetchSharedGame(code)
          .map {
            SubmitGameResponse(
              context: .shared(
                SharedGameResponse(
                  code: $0.code,
                  id: $0.id,
                  gameMode: $0.gameMode,
                  language: $0.language,
                  moves: $0.moves,
                  puzzle: $0.puzzle
                )
              ),
              message: ""
            )
          }

      case .solo:
        guard let leaderboardScore = leaderboardScore else {
          return throwE(ApiError(error: AbsurdError()))
        }
        return sequence(
          TimeScope.soloCases
            .map { timeScope in
              request.database.fetchLeaderboardSummary(
                .init(
                  gameMode: leaderboardScore.gameMode,
                  timeScope: timeScope,
                  type: .player(scoreId: leaderboardScore.id, playerId: conn.data.currentPlayer.id)
                )
              )
              .map { rank in (timeScope, rank) }
            }
        )
        .map {
          SubmitGameResponse(
            context: .solo(.init(ranks: Dictionary($0, uniquingKeysWith: { $1 }))),
            message: praise(mode: leaderboardScore.gameMode, score: leaderboardScore.score)
          )
        }

      case .turnBased:
        return pure(.init(context: .turnBased, message: ""))
      }
    }
    .run
    .flatMap { errorOrSummary in
      switch errorOrSummary {
      case let .left(error):
        return conn.map(const(.left(ApiError(error: error))))
          |> writeStatus(.badRequest)

      case let .right(summary):
        return conn.map(const(.right(summary)))
          |> writeStatus(.ok)
      }
    }
}

struct AbsurdError: Error {}
struct VerificationFailed: Error {}

private func praise(rank: Int, outOf: Int) -> String {
  switch (rank, Double(rank) / Double(outOf)) {
  case (1, _):
    return "Numero uno!"
  case (2, _):
    return "Silver!"
  case (3, _):
    return "Bronze!"
  case (...10, _):
    return "Top ten!"
  case (_, ..<0.001):
    return "Amazing!"
  case (_, ..<0.01):
    return "Great job!"
  case (_, ..<0.10):
    return "Not bad!"
  case (_, ..<0.50):
    return "Keep it up!"
  default:
    return "You can do it!"
  }
}

private func praise(mode: GameMode, score: Int) -> String {
  switch (score, mode) {
  case (0, _):
    return "You there?"
  case (..<250, _):
    return "You can do it!"
  case (..<500, .timed), (..<1_000, .unlimited):
    return "Keep it up!"
  case (..<1_000, .timed), (..<3_000, .unlimited):
    return "Not bad!"
  case (..<2_000, .timed), (..<5_000, .unlimited):
    return "Great job!"
  case (..<3_000, .timed), (..<7_000, .unlimited):
    return "Amazing!"
  case (..<4_000, .timed), (..<9_000, .unlimited):
    return "Outstanding!"
  case (4_000..., .timed), (9_000..., .unlimited):
    return "Unbelievable!"
  default:
    return "Nice job!"
  }
}
