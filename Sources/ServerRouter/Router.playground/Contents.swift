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
  .match(string: "https://www.isowords.xyz/") // .home

router
  .match(string: "https://www.isowords.xyz/privacy-policy") // .privacyPolicy

router.request(for: .api(.init(accessToken: .init(rawValue: UUID()), isDebug: false, route: .dailyChallenge(.today(language: .en)))))

router
  .match(string: "api/daily-challenges/today?accessToken=deadbeef-dead-beef-dead-beefdeadbeef&language=en")
router
  .match(string: "api/daily-challenges")


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
              .removeCube
            ]
          )
        )
      )
    )
  )
)

//api/daily-challenges/today?accessToken=3EE1B177-CCCD-4E75-838B-B5F6AF5068F5&language=en
