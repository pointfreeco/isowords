import Foundation
import ServerRouter
import SharedModels

let router = ServerRouter.router(
  date: Date.init,
  decoder: JSONDecoder(),
  encoder: JSONEncoder(),
  secrets: ["deadbeef"],
  sha256: { $0 }
)

router
  .match(string: "https://www.isowords.xyz/")

router
  .match(string: "https://www.isowords.xyz/privacy-policy")

router
  .request(
    for: .api(
      .init(
        accessToken: .init(rawValue: UUID()),
        isDebug: false,
        route: .dailyChallenge(.today(language: .en))
      )
    )
  )

router
  .match(
    string:
      "api/daily-challenges/today?accessToken=deadbeef-dead-beef-dead-beefdeadbeef&language=en"
  )
router
  .match(string: "api/daily-challenges")

router
  .request(for: .appSiteAssociation)

router
  .request(
    for: .api(
      .init(
        accessToken: .init(rawValue: UUID()),
        isDebug: false,
        route: .dailyChallenge(.today(language: .en))
      )
    )
  )

router.request(
  for: .api(
    .init(
      accessToken: .init(rawValue: UUID()),
      isDebug: false,
      route: .games(
        .submit(
          .init(
            gameContext: .solo(
              .init(
                gameMode: .timed,
                language: .en,
                puzzle: .mock
              )
            ),
            moves: [
              .highScoringMove,
              .removeCube,
            ]
          )
        )
      )
    )
  )
)
