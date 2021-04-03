import Foundation
import ServerRouter
import SharedModels

let r = router(
  date: Date.init,
  decoder: JSONDecoder(),
  encoder: JSONEncoder(),
  secrets: ["deadbeef"],
  sha256: { $0 }
)

r.absoluteString(
  for: .api(
    .init(
      accessToken: .init(rawValue: UUID()),
      isDebug: false,
      route: .changelog(build: 1))
  )
)

r.match(string: "/api/changelog?accessToken=deadbeef-dead-beef-dead-beefdeadbeef&build=1")
