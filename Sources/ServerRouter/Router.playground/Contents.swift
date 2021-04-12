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
  .request(for: .home)
