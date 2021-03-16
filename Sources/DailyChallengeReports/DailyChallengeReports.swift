import DatabaseClient
import Either
import MailgunClient
import Prelude
import SharedModels
import SnsClient

extension ApsPayload where Content == PushNotificationContent {
  init?(results: [DatabaseClient.DailyChallengeReportResult]) {
    guard !results.isEmpty else { return nil }

    func emoji(for rank: Int) -> Character? {
      switch rank {
      case 1: return "🥇"
      case 2: return "🥈"
      case 3: return "🥉"
      case ...10: return "🏆"
      case ...100: return "🏅"
      default: return nil
      }
    }

    func punctuation(for rank: Int, outOf: Int) -> String {
      switch Double(rank) / Double(outOf) {
      case 0..<0.1: return "!"
      default: return "."
      }
    }

    let rankedResults =
      results
      .compactMap { result in result.rank.map { (rank: $0, result: result) } }
      .sorted(by: their(\.rank, <))

    let message: String
    if rankedResults.count == 2 {
      let ((highRank, high), (lowRank, low)) = (rankedResults[0], rankedResults[1])
      message = """
        Today’s challenge is ready! Yesterday’s results:
          \(emoji(for: highRank) ?? "✔️") \(high.gameMode.rawValue.capitalized): \
        you ranked #\(highRank) out of \(high.outOf)\
        \(punctuation(for: highRank, outOf: high.outOf))
          \(emoji(for: lowRank) ?? "✔️") \(low.gameMode.rawValue.capitalized): \
        #\(lowRank) out of \(low.outOf)\
        \(punctuation(for: lowRank, outOf: low.outOf))
        Play again today!
        """
    } else if !rankedResults.isEmpty {
      let (rank, result) = rankedResults[0]
      message = """
        \(emoji(for: rank).map { "\($0) " } ?? "")You ranked #\(rank) out of \
        \(result.outOf) on yesterday’s \(result.gameMode.rawValue) challenge\
        \(punctuation(for: rank, outOf: result.outOf)) Today’s is ready. Play now!
        """
    } else {
      message = """
        Today’s challenge is ready. Play now!
        """
    }

    self.init(
      aps: .init(
        alert: .init(
          actionLocalizedKey: nil,
          body: message,
          localizedArguments: nil,
          localizedKey: nil,
          sound: nil,
          title: "Daily Challenge"
        )
      ),
      content: PushNotificationContent.dailyChallengeReport
    )
  }
}

public func sendDailyChallengeReports(
  database: DatabaseClient,
  sns: SnsClient
) -> EitherIO<Error, Void> {

  let sendPushes = sequence(
    GameMode.allCases.flatMap { gameMode in
      Language.allCases.map { language in
        (gameMode, language)
      }
    }
    .map { gameMode, language in
      database.fetchDailyChallengeReport(.init(gameMode: gameMode, language: language))
    }
  )
  .flatMap { results -> EitherIO<Error, [PublishResponse]> in
    sequence(
      Dictionary(grouping: results.flatMap { $0 }, by: \.arn).map { arn, results in
        ApsPayload(results: results)
          .map { sns.publish(targetArn: arn, payload: $0) }
          ?? pure(PublishResponse(response: .init(result: .init(messageId: ""))))
      }
    )
  }

  return sendPushes.map { _ in () }
}
