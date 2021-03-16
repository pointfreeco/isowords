import Either
import Foundation
import Prelude
import SharedModels
import SiteMiddleware
import SnsClient

public func sendDailyChallengeEndsSoonNotifications(
  environment: Environment
) -> EitherIO<Error, [Either<Error, PublishResponse>]> {
  environment.database.fetchActiveDailyChallengeArns()
    .flatMap { arns in
      lift(
        sequence(
          arns
            .map { dailyChallengeArn -> Parallel<Either<Error, PublishResponse>> in
              let seconds =
                dailyChallengeArn.endsAt.timeIntervalSinceReferenceDate
                - environment.date().timeIntervalSinceReferenceDate
              let minutes = Int(seconds / 60)
              let body = """
                ⏳ The daily challenge ends in \(minutes) minutes! Finish your game before it’s over.
                """

              return environment.snsClient.publish(
                targetArn: dailyChallengeArn.arn,
                payload: ApsPayload(
                  aps: .init(
                    alert: .init(
                      actionLocalizedKey: nil,
                      body: body,
                      localizedArguments: nil,
                      localizedKey: nil,
                      sound: nil,
                      title: "Daily Challenge Ends Soon"
                    )
                  ),
                  content: PushNotificationContent.dailyChallengeEndsSoon
                )
              )
              .run
              .parallel
            }
        )
        .sequential
      )
    }
}
